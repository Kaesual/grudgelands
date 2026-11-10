// Scene coordinates are Luanti nodes; the shared viewer reflects Z into Three.
// Body catalogue units: 0.0525 nodes per pixel (armor-format.md, section 1).
function placePortrait(root, spec, stature = spec.portrait.stature, yaw = .22) {
  const [x, y, z] = spec.portrait.feet;
  root.position.set(x, y, -z);
  root.scale.setScalar(spec.portrait.units_per_pixel * stature);
  root.rotation.y = yaw;
}

// Match a centered object-fit:cover crop of the saved background exactly.
// Widening the panel crops the source vertically; narrow panels crop its sides.
function fitPortraitCamera(camera, spec, width, height, sourceWidth, sourceHeight) {
  const scale = Math.max(width / sourceWidth, height / sourceHeight);
  const tangent = Math.tan(spec.camera.fov * Math.PI / 360);
  camera.fov = 2 * Math.atan(tangent * height / (sourceHeight * scale)) * 180 / Math.PI;
  camera.aspect = width / height;
  camera.position.set(spec.camera.eye[0], spec.camera.eye[1], -spec.camera.eye[2]);
  camera.lookAt(spec.camera.target[0], spec.camera.target[1], -spec.camera.target[2]);
  camera.updateProjectionMatrix();
  camera.updateMatrixWorld();
}
