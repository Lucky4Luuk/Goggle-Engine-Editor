#define SAMPLES 128 //More samples means better image quality.

#define AA 1 //The amount of MSAA. Usually not needed, as it's quite heavy.
//The engine already uses FXAA too.

#define GI 1 //Switch between the old, non-PBR lighting system and the new lighting system.
//GI = 1 means the new lighting system. Right now, it doesn't actually control GI, as there is none.

#define BUMP_FACTOR 0.015 //Leave like this if you don't know what you are doing.
//Just a basic multiplier for the BUMP_FACTOR, although it's not used right now.

#define STEP_SIZE 1 //If bigger, it might get glitchy but might also speed up.
//Leave at 1 if you don't know what you are doing.
//Putting it lower than 1 might help with the accuracy of distance fields.

#define CHECKERBOARD 1 //Turns on checkerboard rendering. Renders every other pixel, interpolates the rest.
