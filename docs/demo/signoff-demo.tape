# VHS tape for the signoff demo GIF.  Render:  vhs docs/demo/signoff-demo.tape
# Requires: charmbracelet/vhs (brew install vhs). Output → docs/demo.gif
Output docs/demo.gif

Set Shell bash
Set FontSize 15
Set Width 1080
Set Height 760
Set Padding 24
Set Theme "GruvboxDark"
Set TypingSpeed 30ms
Set PlaybackSpeed 1.0

Hide
Type "clear && bash docs/demo/replay.sh" Enter
Sleep 700ms
Show
Sleep 11s
