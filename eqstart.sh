#!/usr/bin/env bash

# EverQuest with non-GUI midi support w/o buggy/discontinued directsound.

# This can be executed from Lutris, Runs fluidsynth only when EQ client is running.
#    Configure -> System Options tab -> Pre-launch script
#    Simply install the fluidsynth and fluidsynth-fluid packages,
#    or use your own soundfont.

pgrep fluidsynth &> /dev/null
if [[ "$?" -gt 0 ]]; then
   fluidsynth -a alsa -m alsa_seq -i -C off -R off -g 0.3 -s /usr/share/soundfonts/FluidR3_GM.sf2 &> /dev/null &
fi
exit 0
