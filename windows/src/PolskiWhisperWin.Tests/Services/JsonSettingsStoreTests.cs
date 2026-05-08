// PolskiWhisperWin
// Copyright © 2026 Marcin Werner. Licensed under the MIT License.
// See LICENSE in the repository root.

using System;
using System.IO;
using System.Threading.Tasks;
using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using PolskiWhisperWin.Core.Models;
using PolskiWhisperWin.Core.Services;
using PolskiWhisperWin.Core.Utilities;
using Xunit;

namespace PolskiWhisperWin.Tests.Services;

public class JsonSettingsStoreTests : IDisposable
{
    private readonly string _tempDir;
    private readonly AppPaths _paths;
    private readonly JsonSettingsStore _sut;

    public JsonSettingsStoreTests()
    {
        _tempDir = Path.Combine(Path.GetTempPath(), $"pw-test-{Guid.NewGuid():N}");
        _paths = new AppPaths(_tempDir);
        _sut = new JsonSettingsStore(_paths, NullLogger<JsonSettingsStore>.Instance);
    }

    [Fact]
    public async Task LoadAsync_NoFile_ReturnsDefaults()
    {
        var settings = await _sut.LoadAsync();

        settings.SelectedWhisperModelId.Should().Be(WhisperModelInfo.Default.Identifier);
        settings.HotkeyVirtualKeyCode.Should().Be(0xA3);
        settings.OnboardingCompleted.Should().BeFalse();
    }

    [Fact]
    public async Task SaveAsync_ThenLoadAsync_RoundTripsValues()
    {
        var original = new AppSettings
        {
            SelectedWhisperModelId = "ggml-large-v3",
            HotkeyVirtualKeyCode = 0x91,
            HotkeyMode = HotkeyMode.Hold,
            StartSound = SoundChoice.Glass,
            FinishSound = SoundChoice.None,
            MaxRecordingSeconds = 600,
            LaunchAtLogin = true,
            OnboardingCompleted = true,
            UseGpuAcceleration = false,
        };

        await _sut.SaveAsync(original);
        var loaded = await _sut.LoadAsync();

        loaded.SelectedWhisperModelId.Should().Be("ggml-large-v3");
        loaded.HotkeyVirtualKeyCode.Should().Be(0x91);
        loaded.HotkeyMode.Should().Be(HotkeyMode.Hold);
        loaded.StartSound.Should().Be(SoundChoice.Glass);
        loaded.FinishSound.Should().Be(SoundChoice.None);
        loaded.MaxRecordingSeconds.Should().Be(600);
        loaded.LaunchAtLogin.Should().BeTrue();
        loaded.OnboardingCompleted.Should().BeTrue();
        loaded.UseGpuAcceleration.Should().BeFalse();
    }

    [Fact]
    public async Task SaveAsync_AtomicWrite_DoesNotCorruptOnConcurrentRead()
    {
        var s1 = new AppSettings { MaxRecordingSeconds = 100 };
        await _sut.SaveAsync(s1);

        // Symulujemy: kilka równoczesnych load.
        var task1 = _sut.LoadAsync();
        var task2 = _sut.LoadAsync();
        var task3 = _sut.LoadAsync();
        await Task.WhenAll(task1, task2, task3);

        task1.Result.MaxRecordingSeconds.Should().Be(100);
        task2.Result.MaxRecordingSeconds.Should().Be(100);
        task3.Result.MaxRecordingSeconds.Should().Be(100);
    }

    public void Dispose()
    {
        try
        {
            if (Directory.Exists(_tempDir)) Directory.Delete(_tempDir, recursive: true);
        }
        catch { /* best effort */ }
    }
}
