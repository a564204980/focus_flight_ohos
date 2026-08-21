/*
 * Pure WebGL Volumetric Cloudscape Shader (Raymarching fBM)
 * High-performance 60-120fps hardware accelerated procedural stratosphere cloud sea
 */

(function() {
  const canvas = document.getElementById('glCanvas');
  const gl = canvas.getContext('webgl', { antialias: false, depth: false, preserveDrawingBuffer: false }) ||
             canvas.getContext('experimental-webgl');

  if (!gl) {
    console.error('WebGL not supported');
    return;
  }

  // Handle high-DPI
  function resize() {
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = window.innerWidth * dpr;
    canvas.height = window.innerHeight * dpr;
    gl.viewport(0, 0, canvas.width, canvas.height);
  }
  window.addEventListener('resize', resize);
  resize();

  const vsSource = `
    attribute vec2 a_pos;
    varying vec2 v_uv;
    void main() {
      v_uv = a_pos * 0.5 + 0.5;
      gl_Position = vec4(a_pos, 0.0, 1.0);
    }
  `;

  const fsSource = `
    precision highp float;
    varying vec2 v_uv;
    uniform vec2 u_resolution;
    uniform float u_time;
    uniform int u_mode; // 0: day, 1: sunset, 2: night

    // Pseudo-random & 3D Value Noise
    float hash(vec3 p) {
      p = fract(p * 0.3183099 + .1);
      p *= 17.0;
      return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
    }

    float noise(in vec3 x) {
      vec3 i = floor(x);
      vec3 f = fract(x);
      f = f * f * (3.0 - 2.0 * f);
      return mix(
        mix(mix(hash(i + vec3(0,0,0)), hash(i + vec3(1,0,0)), f.x),
            mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
        mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x),
            mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y),
        f.z
      );
    }

    // 4-Octave 3D Fractal Brownian Motion for puffy cloud volumes
    float fbm(vec3 p) {
      float f = 0.0;
      f += 0.5000 * noise(p); p *= 2.04;
      f += 0.2500 * noise(p); p *= 2.02;
      f += 0.1250 * noise(p); p *= 2.03;
      f += 0.0625 * noise(p);
      return f;
    }

    // Cloud density mapping in 3D world space
    float mapCloudDensity(vec3 p) {
      float h = p.y;
      // Cloud deck between y = -0.6 and y = 1.6
      float heightFactor = smoothstep(-0.8, 0.1, h) * smoothstep(1.8, 0.3, h);
      if (heightFactor <= 0.001) return 0.0;

      // Constant wind drift
      vec3 q = p * 0.42 + vec3(u_time * 0.045, 0.0, u_time * 0.015);
      float d = fbm(q) - 0.44;
      return max(0.0, d) * heightFactor * 3.8;
    }

    void main() {
      vec2 st = (gl_FragCoord.xy - 0.5 * u_resolution.xy) / u_resolution.y;

      // Camera setup looking downward-forward out the airplane window
      vec3 ro = vec3(0.0, 1.8, -3.5); // Camera altitude
      vec3 target = vec3(0.0, -0.2, 5.0);
      vec3 ww = normalize(target - ro);
      vec3 uu = normalize(cross(ww, vec3(0.0, 1.0, 0.0)));
      vec3 vv = cross(uu, ww);
      vec3 rd = normalize(st.x * uu + st.y * vv + 1.25 * ww);

      // Lighting parameters (Golden Sunset / Azure Day / Midnight)
      vec3 sunDir = normalize(vec3(0.4, 0.35, 1.0));
      vec3 skyTop, skyHorizon, sunGlowColor, cloudShadow, cloudLit;

      if (u_mode == 1) {
        // Sunset Mode
        skyTop = vec3(0.12, 0.15, 0.35); // Deep twilight violet
        skyHorizon = vec3(0.98, 0.62, 0.38); // Amber gold
        sunGlowColor = vec3(1.0, 0.82, 0.55);
        cloudShadow = vec3(0.32, 0.22, 0.38); // Purple shadow
        cloudLit = vec3(1.0, 0.88, 0.72); // Warm golden highlight
      } else if (u_mode == 2) {
        // Night Mode
        skyTop = vec3(0.02, 0.03, 0.08);
        skyHorizon = vec3(0.06, 0.09, 0.16);
        sunGlowColor = vec3(0.4, 0.5, 0.7);
        cloudShadow = vec3(0.04, 0.05, 0.09);
        cloudLit = vec3(0.20, 0.24, 0.35);
      } else {
        // Day Mode
        skyTop = vec3(0.12, 0.38, 0.78); // Stratosphere blue
        skyHorizon = vec3(0.72, 0.86, 0.98); // Crisp white-blue horizon
        sunGlowColor = vec3(1.0, 0.98, 0.92);
        cloudShadow = vec3(0.60, 0.68, 0.82); // Soft ambient blue shadow
        cloudLit = vec3(1.0, 1.0, 1.0); // Pure white highlight
      }

      // Background Sky Dome
      float sunDot = max(0.0, dot(rd, sunDir));
      float horizonFactor = clamp((rd.y + 0.15) * 1.8, 0.0, 1.0);
      vec3 skyColor = mix(skyHorizon, skyTop, horizonFactor);
      skyColor += sunGlowColor * pow(sunDot, 16.0) * 0.45; // Sun halo
      skyColor += sunGlowColor * pow(sunDot, 64.0) * 0.80; // Sun core

      // Volumetric Cloud Raymarching
      vec4 cloudSum = vec4(0.0);
      float t = 1.0;
      float maxDist = 20.0;
      float stepSize = 0.20;

      for (int i = 0; i < 40; i++) {
        if (cloudSum.a > 0.96 || t > maxDist) break;
        vec3 pos = ro + rd * t;
        float dens = mapCloudDensity(pos);

        if (dens > 0.01) {
          // March toward sun for optical depth / self-shadowing
          float lDist = 0.38;
          float lDens = mapCloudDensity(pos + sunDir * lDist);
          float shadow = clamp(exp(-lDens * 2.5), 0.0, 1.0);

          // Silver Lining forward scattering
          float henyey = 0.5 * (1.0 - 0.36) / pow(1.0 + 0.36 - 1.2 * sunDot, 1.5);
          vec3 col = mix(cloudShadow, cloudLit * (1.0 + henyey * 1.2), shadow);

          float alpha = (1.0 - exp(-dens * stepSize)) * (1.0 - cloudSum.a);
          cloudSum.rgb += col * alpha;
          cloudSum.a += alpha;
        }
        t += stepSize + t * 0.018; // Geometric step expansion
      }

      // Final composite: blend sky and clouds
      vec3 finalColor = skyColor * (1.0 - cloudSum.a) + cloudSum.rgb;

      // Subtle atmospheric vignette & film tone
      finalColor = pow(finalColor, vec3(0.92)); // Gamma / tone curve

      gl_FragColor = vec4(finalColor, 1.0);
    }
  `;

  function createShader(gl, type, source) {
    const s = gl.createShader(type);
    gl.shaderSource(s, source);
    gl.compileShader(s);
    if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) {
      console.error(gl.getShaderInfoLog(s));
      gl.deleteShader(s);
      return null;
    }
    return s;
  }

  const vs = createShader(gl, gl.VERTEX_SHADER, vsSource);
  const fs = createShader(gl, gl.FRAGMENT_SHADER, fsSource);
  const prog = gl.createProgram();
  gl.attachShader(prog, vs);
  gl.attachShader(prog, fs);
  gl.linkProgram(prog);
  gl.useProgram(prog);

  const posBuf = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, posBuf);
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([
    -1, -1,
     1, -1,
    -1,  1,
    -1,  1,
     1, -1,
     1,  1
  ]), gl.STATIC_DRAW);

  const aPos = gl.getAttribLocation(prog, 'a_pos');
  gl.enableVertexAttribArray(aPos);
  gl.vertexAttribPointer(aPos, 2, gl.FLOAT, false, 0, 0);

  const uRes = gl.getUniformLocation(prog, 'u_resolution');
  const uTime = gl.getUniformLocation(prog, 'u_time');
  const uMode = gl.getUniformLocation(prog, 'u_mode');

  let currentMode = 1; // Default: Sunset
  window.setLightingMode = function(mode) {
    if (mode === 'day') currentMode = 0;
    else if (mode === 'night') currentMode = 2;
    else currentMode = 1; // sunset
  };

  let startTime = performance.now();
  function render(now) {
    const elapsed = (now - startTime) * 0.001;
    gl.uniform2f(uRes, canvas.width, canvas.height);
    gl.uniform1f(uTime, elapsed);
    gl.uniform1i(uMode, currentMode);

    gl.drawArrays(gl.TRIANGLES, 0, 6);
    requestAnimationFrame(render);
  }
  requestAnimationFrame(render);
})();
