# Charge Sound Changer
Change windows default "beep" charging sound to your liking.<br>
<video controls width="350" src="https://github.com/user-attachments/assets/b7d3d790-ffc2-4a3f-b6a5-9f783a441609"></video>

## Installation
Download latest version in [release](https://github.com/YFHD-osu/Charge-Sound-Changer/releases) page, and put executeable into your desired path <br>

Open the file to generate ``config.yaml`` and set it up <br>
> [!TIP]
> Only ``.wav`` sound files are supported.
```yaml
charger-connect: "\\Path\\to\\wav\\file.wav"
# Make field empty to disable playing sound
charger-disconnect: ""
```

### Run on startup
Directly opening the file will open a terminal window, you can create a ``.vbs`` file to run program in background
```vbs
Dim WinScriptHost
Set WinScriptHost = CreateObject("WScript.Shell")
WinScriptHost.Run Chr(34) & "charge_sound.exe" & Chr(34), 0
Set WinScriptHost = Nothing
```

Put your ``.vbs`` shortcut into your ``shell:startup`` folder to run program when windows startup automatically

### Disable original charge sound
Most of the laptop uses system service to play charge sound, you can check for program in volume mixer, then mute them. <br>
For an example, my laptop uses ``Realtek HD Audio Universal Service``
