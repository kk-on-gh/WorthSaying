# Changelog

## [0.3] - 2026-11-22

### Added
- Themes (Options > Main Window): Dark, a flat dark look with gold accents, and EllesmereUI, which takes on your EllesmereUI look, accent color and font. Both turn checkboxes into toggles and restyle the dropdown menus. Default keeps the gold and parchment.
- Font (Options > Main Window): any font the game has or your other addons share, with every theme.
- The Rehearse button pulses while Rehearse is on.
- The script editor shades every other line, so wrapped lines are easier to tell apart.

### Changed
- Main Window settings are now at the top of the Options tab.

### Fixed
- The editor's Tags, Delay and Triggers rows were a few pixels out of line.

## [0.2] - 2026-11-19

### Added
- Tours! A quick guided walk around Worth Saying, offered the first time you open it and any time from the About tab, plus a "what's new" tour for each new version in its patch notes.
- Play hidden (per speech): starting it from its macro plays it without opening the presenter. When it stops for a Say or Yell key press or a /pause, it says so in chat, and running the macro again carries on.
- The editor shows each speech's macro command, ready to copy.

### Changed
- Running /ws play again for a speech that's stopped partway carries on from where it stopped, instead of starting over. After 60 seconds stopped, it starts over (change this in Options > Playback).
- The delay after each line can go as low as 0.1 seconds, down from 0.5.
- Uses always count now. The "Count uses" option is gone.
- Minor UI adjustments.

## [0.1.1] - 2026-11-18

### Added
- Pick which chat tab gets [Rehearse] lines and Worth Saying's own messages (Options > Playback). Before, they always went to the main chat window, and no chat filter could move them.
- Role tokens: %tank, %healer and %dps name the players in that role, and %rtank, %rhealer and %rdps name one at random. With nobody in a role they say "tank", "healer" or "DPS", which you can change in Options > Playback. The sample quip uses a few.

### Changed
- Searching the speech list also matches trigger places, so "chasm" finds speeches set to pop up in Ragefire Chasm.
- Token placeholders in the Preview, like target and zone, are highlighted in gold so they stand out from the rest of the line.
- Refreshed the addon icons.
- The minimap button now shows its full name in minimap button collectors, such as EllesmereUI's flyout. If you had ungrouped it in EllesmereUI, ungroup it once more, since EllesmereUI remembers ungrouped buttons by their old name.

## [0.1.0] - 2026-11-11

First version of Worth Saying! Write speeches, tours, RP scripts and one-liners ahead of time, then deliver them to chat one line at a time, by hand or on a timer.

### Added
- A speech library: save as many speeches as you like, with tags, favorites, searching, filtering and sortable, resizable columns.
- A script editor that saves as you type, with undo and redo (Ctrl+Z, Ctrl+Y) and a meter showing how many characters are left on the current line.
- A color-coded Preview that shows each line exactly as it'll be sent, with tokens shown as readable names like "target" and "zone", and flags unknown commands and lines too long for chat. Click a line to start presenting from it.
- Every chat channel: /s, /y, /e, /p, /ra, /rw, /i, /g, /o, /w and /1 to /9, plus /gr, which picks party, raid or instance chat for you.
- Every built-in emote, like /bow, /wave and /cheer, on its own line or in curly braces to go with a line: {cheer} Let's go!
- Control lines: /wait for a longer or shorter pause, /pause to hold auto-play until you continue (with an optional note), ## headings for sections you can jump to, and // notes that are never sent.
- Tokens that fill in when a line is sent: %t and %tt (target's first and full name), %p, %z, %sz, %c, %r, %lvl, %g, %l, %time and more.
- The presenter: the line up next and the one after, a progress bar, a section dropdown, and Restart, Back, Send, Skip and Play buttons. It can shrink to a tiny bar of just the playback buttons.
- Auto-play with a delay after each line, optional extra time for longer lines, and action emotes that play right after the line before them. Say, Yell and numbered channels can't be sent on a timer outside instances, so auto-play pauses on those and waits for your key press.
- Long lines are split at a sentence break and sent as separate messages, each with its own delay.
- Optional sounds when auto-play needs your key press, when it pauses, and when a speech finishes, each with a choice of sound.
- Rehearse mode, which prints lines only to your own chat window, with an option to still perform emotes. Rehearsals don't count toward a speech's Uses.
- Quips: speeches that send one random line each time. Put /ws quip and the speech's name in a macro to fire one from your action bar.
- Triggers: a speech can pop up the presenter when you enter an instance, zone or subzone, or join a group. Pick instances from a list of every dungeon and raid. With several speeches for the same place, one is picked (random, random favorite, most used, least used, last used or longest unused) and the others are a click away.
- Import and export strings for sharing speeches.
- Keybinds for Send, Back, Play/Pause, the presenter and the main window, plus /ws commands for macros.
- A Guide tab covering everything a script can do, plus a sample tour and a sample quip.
