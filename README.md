
# ParticleCloud shaders
Some shaders + unity setup to have purely shader-based manipulatable particles usable in VRChat
#### Unity package download located in [releases](../../releases)!
**WARNING**: There's a crash bug that can take you and your friends out unexpectedly
Report available at [VRChat Canny](https://vrchat.canny.io/bug-reports/p/crash-when-using-grabpass-with-uncommon-format-render-target) *TLDR: triggered by coming in contact with screen-grabbing shaders like zoom/distortion/reflection.  **Usage in public worlds is STRONGLY DISCOURAGED***  
  
**Preview:**
[![Video](https://cdn-b-east.streamable.com/image/hiv2w_1.jpg)](https://streamable.com/s/hiv2w/ujzbhd)

## Usage

 1. Import unity package and add the included prefab from
    _Avatars/Accesories/ParticleCloud/_ to **root** of your avatar
 2. Move the pivots to where you want to be manipulation points (in palms/on legs)
_Attaching is similar as with world particles:_
 4. add _RigidBodies_ to where you want to base the transformations (for eg. wrists), freeze constraints
 5. Link the rigidbodies to fixed joints in _pivot1/2_
 6. The included animations+controller should be enough to demonstrate how to activate and manipulate
 * To use the second pivot, adjust _"Strength"_ material property of the child quad

**Pull requests are greatly appreciated!**

**Made a cool alternation?**
Look me up on discord, I could make a gallery here or in issues

---
Source of *noiseSimplex.cginc*: [In Unity forums](https://forum.unity.com/threads/2d-3d-4d-optimised-perlin-noise-cg-hlsl-library-cginc.218372/)