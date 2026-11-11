local ns = WorthSaying

-- mirrors CHANGELOG.md, newest first. the game can't read that file
ns.CHANGELOG = {
	{
		version = "0.1.0", date = "2026-11-11", shipped = true,
		intro = {
			"First version of Worth Saying! Write speeches, tours, RP scripts and one-liners ahead of time, then deliver them to chat one line at a time, by hand or on a timer.",
		},
		sections = {
			{ heading = "Added", items = {
				"A speech library: save as many speeches as you like, with tags, favorites, searching, filtering and sortable, resizable columns.",
				"A script editor that saves as you type, with undo and redo (Ctrl+Z, Ctrl+Y) and a meter showing how many characters are left on the current line.",
				"A color-coded Preview that shows each line exactly as it'll be sent, with tokens shown as readable names like \"target\" and \"zone\", and flags unknown commands and lines too long for chat. Click a line to start presenting from it.",
				"Every chat channel: /s, /y, /e, /p, /ra, /rw, /i, /g, /o, /w and /1 to /9, plus /gr, which picks party, raid or instance chat for you.",
				"Every built-in emote, like /bow, /wave and /cheer, on its own line or in curly braces to go with a line: {cheer} Let's go!",
				"Control lines: /wait for a longer or shorter pause, /pause to hold auto-play until you continue (with an optional note), ## headings for sections you can jump to, and // notes that are never sent.",
				"Tokens that fill in when a line is sent: %t and %tt (target's first and full name), %p, %z, %sz, %c, %r, %lvl, %g, %l, %time and more.",
				"The presenter: the line up next and the one after, a progress bar, a section dropdown, and Restart, Back, Send, Skip and Play buttons. It can shrink to a tiny bar of just the playback buttons.",
				"Auto-play with a delay after each line, optional extra time for longer lines, and action emotes that play right after the line before them. Say, Yell and numbered channels can't be sent on a timer outside instances, so auto-play pauses on those and waits for your key press.",
				"Long lines are split at a sentence break and sent as separate messages, each with its own delay.",
				"Optional sounds when auto-play needs your key press, when it pauses, and when a speech finishes, each with a choice of sound.",
				"Rehearse mode, which prints lines only to your own chat window, with an option to still perform emotes. Rehearsals don't count toward a speech's Uses.",
				"Quips: speeches that send one random line each time. Put /ws quip and the speech's name in a macro to fire one from your action bar.",
				"Triggers: a speech can pop up the presenter when you enter an instance, zone or subzone, or join a group. Pick instances from a list of every dungeon and raid. With several speeches for the same place, one is picked (random, random favorite, most used, least used, last used or longest unused) and the others are a click away.",
				"Import and export strings for sharing speeches.",
				"Keybinds for Send, Back, Play/Pause, the presenter and the main window, plus /ws commands for macros.",
				"A Guide tab covering everything a script can do, plus a sample tour and a sample quip.",
			}},
		},
	},
}
