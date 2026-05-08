// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using Microsoft.Data.Sqlite;
using Microsoft.Extensions.Logging;
using PolskiWhisperWin.Core.Models;
using PolskiWhisperWin.Core.Utilities;

namespace PolskiWhisperWin.Core.Services;

/// <summary>
/// SQLite-based store dla <see cref="FindReplaceRule"/>.
/// Schema: <c>find_replace_rule(id, find_text, replace_with, is_regex, case_sensitive, order_index, created_at)</c>.
/// </summary>
public sealed class SqliteVocabularyStore : IVocabularyStore, IAsyncDisposable
{
    private readonly IAppPaths _paths;
    private readonly ILogger<SqliteVocabularyStore> _logger;
    private readonly SemaphoreSlim _dbLock = new(1, 1);
    private string ConnectionString => $"Data Source={_paths.VocabularyDatabasePath};";

    public SqliteVocabularyStore(IAppPaths paths, ILogger<SqliteVocabularyStore> logger)
    {
        _paths = paths;
        _logger = logger;
    }

    /// <inheritdoc/>
    public async Task InitializeAsync(CancellationToken cancellationToken = default)
    {
        await _dbLock.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            _paths.EnsureDirectoriesExist();

            await using var connection = new SqliteConnection(ConnectionString);
            await connection.OpenAsync(cancellationToken).ConfigureAwait(false);

            // Tabela schema_version dla migracji.
            const string createSchemaVersion = """
                CREATE TABLE IF NOT EXISTS schema_version (
                    version INTEGER NOT NULL PRIMARY KEY
                );
                """;
            await ExecuteNonQueryAsync(connection, createSchemaVersion, cancellationToken).ConfigureAwait(false);

            // Migracja v1: tabela reguł.
            const string createRulesTable = """
                CREATE TABLE IF NOT EXISTS find_replace_rule (
                    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
                    find_text TEXT NOT NULL,
                    replace_with TEXT NOT NULL,
                    is_regex INTEGER NOT NULL DEFAULT 0,
                    case_sensitive INTEGER NOT NULL DEFAULT 0,
                    order_index INTEGER NOT NULL DEFAULT 0,
                    created_at TEXT NOT NULL
                );
                """;
            await ExecuteNonQueryAsync(connection, createRulesTable, cancellationToken).ConfigureAwait(false);

            const string createIndex = """
                CREATE INDEX IF NOT EXISTS idx_find_replace_rule_order ON find_replace_rule(order_index);
                """;
            await ExecuteNonQueryAsync(connection, createIndex, cancellationToken).ConfigureAwait(false);

            // Mark as v1.
            const string insertVersion = "INSERT OR IGNORE INTO schema_version(version) VALUES (1);";
            await ExecuteNonQueryAsync(connection, insertVersion, cancellationToken).ConfigureAwait(false);

            _logger.LogInformation("VocabularyStore zainicjalizowany w {Path}.", _paths.VocabularyDatabasePath);
        }
        finally
        {
            _dbLock.Release();
        }
    }

    /// <inheritdoc/>
    public async Task<IReadOnlyList<FindReplaceRule>> GetAllRulesAsync(CancellationToken cancellationToken = default)
    {
        await _dbLock.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            await using var connection = new SqliteConnection(ConnectionString);
            await connection.OpenAsync(cancellationToken).ConfigureAwait(false);

            await using var command = connection.CreateCommand();
            command.CommandText = """
                SELECT id, find_text, replace_with, is_regex, case_sensitive, order_index, created_at
                FROM find_replace_rule
                ORDER BY order_index ASC, id ASC;
                """;

            var rules = new List<FindReplaceRule>();
            await using var reader = await command.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);
            while (await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
            {
                rules.Add(new FindReplaceRule(
                    Id: reader.GetInt64(0),
                    FindText: reader.GetString(1),
                    ReplaceWith: reader.GetString(2),
                    IsRegex: reader.GetInt32(3) == 1,
                    CaseSensitive: reader.GetInt32(4) == 1,
                    OrderIndex: reader.GetInt32(5),
                    CreatedAt: DateTime.Parse(reader.GetString(6)).ToUniversalTime()
                ));
            }

            return rules;
        }
        finally
        {
            _dbLock.Release();
        }
    }

    /// <inheritdoc/>
    public async Task<FindReplaceRule> AddRuleAsync(FindReplaceRule rule, CancellationToken cancellationToken = default)
    {
        await _dbLock.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            await using var connection = new SqliteConnection(ConnectionString);
            await connection.OpenAsync(cancellationToken).ConfigureAwait(false);

            // Określ nowy order_index (max + 1).
            await using var maxCmd = connection.CreateCommand();
            maxCmd.CommandText = "SELECT COALESCE(MAX(order_index), -1) + 1 FROM find_replace_rule;";
            var newOrder = (long)(await maxCmd.ExecuteScalarAsync(cancellationToken).ConfigureAwait(false) ?? 0L);

            await using var insertCmd = connection.CreateCommand();
            insertCmd.CommandText = """
                INSERT INTO find_replace_rule(find_text, replace_with, is_regex, case_sensitive, order_index, created_at)
                VALUES ($findText, $replaceWith, $isRegex, $caseSensitive, $orderIndex, $createdAt);
                SELECT last_insert_rowid();
                """;

            insertCmd.Parameters.AddWithValue("$findText", rule.FindText);
            insertCmd.Parameters.AddWithValue("$replaceWith", rule.ReplaceWith);
            insertCmd.Parameters.AddWithValue("$isRegex", rule.IsRegex ? 1 : 0);
            insertCmd.Parameters.AddWithValue("$caseSensitive", rule.CaseSensitive ? 1 : 0);
            insertCmd.Parameters.AddWithValue("$orderIndex", (int)newOrder);
            insertCmd.Parameters.AddWithValue("$createdAt", rule.CreatedAt.ToString("o"));

            var newId = (long)(await insertCmd.ExecuteScalarAsync(cancellationToken).ConfigureAwait(false) ?? 0L);

            return rule with { Id = newId, OrderIndex = (int)newOrder };
        }
        finally
        {
            _dbLock.Release();
        }
    }

    /// <inheritdoc/>
    public async Task UpdateRuleAsync(FindReplaceRule rule, CancellationToken cancellationToken = default)
    {
        if (rule.Id <= 0)
            throw new ArgumentException("Cannot update a rule with Id <= 0. Use AddRuleAsync for new rules.", nameof(rule));

        await _dbLock.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            await using var connection = new SqliteConnection(ConnectionString);
            await connection.OpenAsync(cancellationToken).ConfigureAwait(false);

            await using var command = connection.CreateCommand();
            command.CommandText = """
                UPDATE find_replace_rule
                SET find_text = $findText,
                    replace_with = $replaceWith,
                    is_regex = $isRegex,
                    case_sensitive = $caseSensitive
                WHERE id = $id;
                """;

            command.Parameters.AddWithValue("$findText", rule.FindText);
            command.Parameters.AddWithValue("$replaceWith", rule.ReplaceWith);
            command.Parameters.AddWithValue("$isRegex", rule.IsRegex ? 1 : 0);
            command.Parameters.AddWithValue("$caseSensitive", rule.CaseSensitive ? 1 : 0);
            command.Parameters.AddWithValue("$id", rule.Id);

            await command.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
        }
        finally
        {
            _dbLock.Release();
        }
    }

    /// <inheritdoc/>
    public async Task DeleteRuleAsync(long ruleId, CancellationToken cancellationToken = default)
    {
        await _dbLock.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            await using var connection = new SqliteConnection(ConnectionString);
            await connection.OpenAsync(cancellationToken).ConfigureAwait(false);

            await using var command = connection.CreateCommand();
            command.CommandText = "DELETE FROM find_replace_rule WHERE id = $id;";
            command.Parameters.AddWithValue("$id", ruleId);

            await command.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
        }
        finally
        {
            _dbLock.Release();
        }
    }

    /// <inheritdoc/>
    public async Task ReorderRulesAsync(IReadOnlyList<long> orderedIds, CancellationToken cancellationToken = default)
    {
        await _dbLock.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            await using var connection = new SqliteConnection(ConnectionString);
            await connection.OpenAsync(cancellationToken).ConfigureAwait(false);

            await using var transaction = connection.BeginTransaction();

            for (int i = 0; i < orderedIds.Count; i++)
            {
                await using var command = connection.CreateCommand();
                command.Transaction = transaction;
                command.CommandText = "UPDATE find_replace_rule SET order_index = $idx WHERE id = $id;";
                command.Parameters.AddWithValue("$idx", i);
                command.Parameters.AddWithValue("$id", orderedIds[i]);
                await command.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
            }

            transaction.Commit();
        }
        finally
        {
            _dbLock.Release();
        }
    }

    private static async Task ExecuteNonQueryAsync(SqliteConnection connection, string sql, CancellationToken cancellationToken)
    {
        await using var command = connection.CreateCommand();
        command.CommandText = sql;
        await command.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
    }

    public ValueTask DisposeAsync()
    {
        _dbLock.Dispose();
        return ValueTask.CompletedTask;
    }
}
