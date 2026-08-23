# Reverse-Engineering / Native Note — Audio Render Graph

This is a native-host architecture note, not a claim about the exact Classic Sound Manager implementation.

The original Mac program used persistent Sound Manager channels and a priority/channel-selection routine around PPC `0x1487C` and `0x1B8F0`. The modern AVAudioPlayer-per-trigger approach was therefore never structurally similar to the original channel model.

Milestone 1.4.2 moves the native host closer to the useful observable property of that design: channels/voices exist before an event happens, sample data is resident, and an event submits work to an already-running audio system rather than constructing or starting a standalone player synchronously.

The new backend is intentionally still an engineering layer:

- 16 nodes/sample is capacity, not a recovered Classic channel-count claim;
- exact sound-effect index -> `snd` mapping remains pending;
- exact priority/channel stealing from `0x1487C` / `0x1B8F0` remains pending;
- exact stereo/pan/priority semantics remain pending.

Those can now be recovered on top of an audio graph that is suitable for real-time game playback without reintroducing main-thread `AVAudioPlayer.play()` stalls.
