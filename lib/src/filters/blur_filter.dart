part of stagexl;

class BlurFilter extends BitmapFilter {

  int blurX;
  int blurY;

  //-------------------------------------------------------------------------------------------------
  // Credits to Alois Zingl, Vienna, Austria.
  // Extended Binomial Filter for Fast Gaussian Blur
  // http://members.chello.at/easyfilter/gauss.html
  // http://members.chello.at/easyfilter/gauss.pdf
  //-------------------------------------------------------------------------------------------------

  BlurFilter([this.blurX = 4, this.blurY = 4]) {
    if (blurX < 0 || blurY < 0) {
      throw new ArgumentError("Error #9004: The minimum blur size is 0.");
    }
    if (blurX > 64 || blurY > 64) {
      throw new ArgumentError("Error #9004: The maximum blur size is 64.");
    }
  }

  BitmapFilter clone() => new BlurFilter(blurX, blurY);
  Rectangle get overlap => new Rectangle(-blurX, -blurY, 2 * blurX, 2 * blurY);
  int get passCount => 2;

  //-------------------------------------------------------------------------------------------------

  void apply(BitmapData bitmapData, [Rectangle rectangle]) {

    RenderTextureQuad renderTextureQuad = rectangle == null
        ? bitmapData.renderTextureQuad
        : bitmapData.renderTextureQuad.cut(rectangle);

    ImageData imageData = renderTextureQuad.getImageData();
    List<int> data = imageData.data;
    int width = _ensureInt(imageData.width);
    int height = _ensureInt(imageData.height);

    num pixelRatio = renderTextureQuad.renderTexture.storePixelRatio;
    int blurX = (this.blurX * pixelRatio).round();
    int blurY = (this.blurY * pixelRatio).round();
    int stride = width * 4;

    _premultiplyAlpha(data);

    for (int x = 0; x < width; x++) {
      _blur2(data, x * 4 + 0, height, stride, blurY);
      _blur2(data, x * 4 + 1, height, stride, blurY);
      _blur2(data, x * 4 + 2, height, stride, blurY);
      _blur2(data, x * 4 + 3, height, stride, blurY);
    }

    for (int y = 0; y < height; y++) {
      _blur2(data, y * stride + 0, width, 4, blurX);
      _blur2(data, y * stride + 1, width, 4, blurX);
      _blur2(data, y * stride + 2, width, 4, blurX);
      _blur2(data, y * stride + 3, width, 4, blurX);
    }

    _unpremultiplyAlpha(data);

    renderTextureQuad.putImageData(imageData);
  }

  //-------------------------------------------------------------------------------------------------

  void renderFilter(RenderState renderState, RenderTextureQuad renderTextureQuad, int pass) {
    RenderContextWebGL renderContext = renderState.renderContext;
    RenderTexture renderTexture = renderTextureQuad.renderTexture;
    renderContext._updateState(_blurProgram, renderTexture);

    if (pass == 0) {
      _blurProgram.updateRenderingContext(1 / renderTexture.width, 0.0);
    } else {
      _blurProgram.updateRenderingContext(0.0, 1 / renderTexture.height);
    }

    _blurProgram.renderQuad(renderState, renderTextureQuad);
  }
}

//-------------------------------------------------------------------------------------------------
//-------------------------------------------------------------------------------------------------

final _blurProgram = new _BlurProgram();

class _BlurProgram extends _BitmapFilterProgram {

  String get fragmentShaderSource => """
      precision mediump float;
      uniform sampler2D uSampler;
      uniform vec2 uBlur;
      varying vec2 vTextCoord;
      varying float vAlpha;
      void main() {
        vec4 color = vec4(0);
        color += texture2D(uSampler, vec2(vTextCoord - 4.0 * uBlur)) * 0.050;
        color += texture2D(uSampler, vec2(vTextCoord - 3.0 * uBlur)) * 0.090;
        color += texture2D(uSampler, vec2(vTextCoord - 2.0 * uBlur)) * 0.120;
        color += texture2D(uSampler, vec2(vTextCoord - 1.0 * uBlur)) * 0.155;
        color += texture2D(uSampler, vec2(vTextCoord +       uBlur)) * 0.170;
        color += texture2D(uSampler, vec2(vTextCoord + 1.0 * uBlur)) * 0.155;
        color += texture2D(uSampler, vec2(vTextCoord + 2.0 * uBlur)) * 0.120;
        color += texture2D(uSampler, vec2(vTextCoord + 3.0 * uBlur)) * 0.090;
        color += texture2D(uSampler, vec2(vTextCoord + 4.0 * uBlur)) * 0.050;
        gl_FragColor = color * vAlpha;
      }
      """;

   void updateRenderingContext(num blurX, num blurY) {
     // either blurX or blurY must be zero!
     var uBlurLocation = _uniformLocations["uBlur"];
     _renderingContext.uniform2f(uBlurLocation, blurX, blurY);
   }

}
