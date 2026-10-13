export class Renderer {
  constructor(canvas) {
    this.canvas = canvas;
    const gl = this.gl = canvas.getContext('webgl', { alpha: true, premultipliedAlpha: true, antialias: true });
    if (!gl) throw new Error('浏览器未启用 WebGL，请开启硬件加速后重试。');
    const shader = (type, source) => {
      const result = gl.createShader(type); gl.shaderSource(result, source); gl.compileShader(result);
      if (!gl.getShaderParameter(result, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(result));
      return result;
    };
    const vs = shader(gl.VERTEX_SHADER, 'attribute vec2 a_position; attribute vec2 a_uv; varying vec2 v_uv; void main(){gl_Position=vec4(a_position,0.,1.);v_uv=a_uv;}');
    const fs = shader(gl.FRAGMENT_SHADER, 'precision mediump float; varying vec2 v_uv; uniform sampler2D u_image; uniform vec4 u_color; void main(){vec4 c=texture2D(u_image,v_uv)*u_color; gl_FragColor=vec4(c.rgb*c.a,c.a);}');
    this.program = gl.createProgram(); gl.attachShader(this.program, vs); gl.attachShader(this.program, fs); gl.linkProgram(this.program);
    if (!gl.getProgramParameter(this.program, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(this.program));
    gl.deleteShader(vs); gl.deleteShader(fs); gl.useProgram(this.program);
    this.vertexBuffer = gl.createBuffer(); this.indexBuffer = gl.createBuffer();
    const pos = gl.getAttribLocation(this.program, 'a_position'), uv = gl.getAttribLocation(this.program, 'a_uv');
    gl.bindBuffer(gl.ARRAY_BUFFER, this.vertexBuffer);
    gl.enableVertexAttribArray(pos); gl.vertexAttribPointer(pos, 2, gl.FLOAT, false, 16, 0);
    gl.enableVertexAttribArray(uv); gl.vertexAttribPointer(uv, 2, gl.FLOAT, false, 16, 8);
    this.color = gl.getUniformLocation(this.program, 'u_color');
    this.textures = new Map();
    gl.enable(gl.BLEND); gl.enable(gl.SCISSOR_TEST);
    canvas.addEventListener('webglcontextlost', event => { event.preventDefault(); window.dispatchEvent(new CustomEvent('rendererror', { detail: '显卡绘图连接已中断，请刷新页面重新加载。' })); });
  }
  texture(image) {
    if (this.textures.has(image)) return this.textures.get(image);
    const gl = this.gl;
    if (image.width > gl.getParameter(gl.MAX_TEXTURE_SIZE) || image.height > gl.getParameter(gl.MAX_TEXTURE_SIZE)) throw new Error('图集超过当前显卡的最大纹理尺寸');
    const texture = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D, texture);
    gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, false);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, image);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    this.textures.set(image, texture);
    return texture;
  }
  release(images) {
    for (const image of images.values()) {
      const texture = this.textures.get(image);
      if (texture) this.gl.deleteTexture(texture);
      this.textures.delete(image);
    }
  }
  clear() {
    const ratio = this.ratio = Math.min(window.devicePixelRatio || 1, 2);
    const w = Math.round(innerWidth * ratio), h = Math.round(innerHeight * ratio);
    if (this.canvas.width !== w || this.canvas.height !== h) { this.canvas.width = w; this.canvas.height = h; }
    const gl = this.gl;
    gl.scissor(0, 0, w, h); gl.clearColor(0, 0, 0, 0); gl.clear(gl.COLOR_BUFFER_BIT);
  }
  draw(effect, rect, zoom = 1) {
    if (rect.bottom <= 0 || rect.top >= innerHeight || !rect.width || !rect.height) return;
    const gl = this.gl, dpr = this.ratio;
    gl.viewport(Math.round(rect.left * dpr), Math.round((innerHeight - rect.bottom) * dpr), Math.round(rect.width * dpr), Math.round(rect.height * dpr));
    gl.scissor(Math.round(rect.left * dpr), Math.round((innerHeight - rect.bottom) * dpr), Math.round(rect.width * dpr), Math.round(rect.height * dpr));
    const bounds = effect.bounds;
    const scale = Math.min(rect.width / bounds.width, rect.height / bounds.height) * 0.82 * zoom;
    effect.geometry(({ vertices, indices, uvs, color, image, blend }) => {
      const buffer = new Float32Array(vertices.length * 2);
      for (let i = 0; i < vertices.length; i += 2) {
        buffer[i * 2] = (vertices[i] - bounds.x) * scale * 2 / rect.width;
        buffer[i * 2 + 1] = (vertices[i + 1] - bounds.y) * scale * 2 / rect.height;
        buffer[i * 2 + 2] = uvs[i]; buffer[i * 2 + 3] = uvs[i + 1];
      }
      gl.bindTexture(gl.TEXTURE_2D, this.texture(image));
      if (blend === 1) gl.blendFuncSeparate(gl.ONE, gl.ONE, gl.ZERO, gl.ONE);
      else if (blend === 2) gl.blendFuncSeparate(gl.DST_COLOR, gl.ONE_MINUS_SRC_ALPHA, gl.ONE, gl.ONE_MINUS_SRC_ALPHA);
      else if (blend === 3) gl.blendFuncSeparate(gl.ONE, gl.ONE_MINUS_SRC_COLOR, gl.ONE, gl.ONE_MINUS_SRC_ALPHA);
      else gl.blendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA);
      gl.uniform4fv(this.color, color);
      gl.bindBuffer(gl.ARRAY_BUFFER, this.vertexBuffer); gl.bufferData(gl.ARRAY_BUFFER, buffer, gl.DYNAMIC_DRAW);
      gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, this.indexBuffer); gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, new Uint16Array(indices), gl.DYNAMIC_DRAW);
      gl.drawElements(gl.TRIANGLES, indices.length, gl.UNSIGNED_SHORT, 0);
    });
  }
}
