# FaceFT
MATLAB & Psychtoolbox. Steady-state visually evoked potential experiment.

Human faces are modulated (default 6 Hz) in a sinusoidal fade in/out presentation. On some trials, the same face is repeated, on others it switches 1/3 of the way through after being adapted to the initial face. 

Dependencies: Psychtoolbox, http://www.psychtoolbox.org

Equipment: this is intended to be run with EEG equipment (Biosemi ActiveTwo or EGI HydroCel). It will not record useful data without it. Turn on flag "EEG" to allow this. String "EEGt" also chooses which equipment.

Resources: faces taked from Radboud Face Database (Langner et al., 2010). Faces were oval cropped to remove shape and hair cues.
