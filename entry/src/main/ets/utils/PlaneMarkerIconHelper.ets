import { image } from '@kit.ImageKit';

/**
 * Plane Map Marker PixelMap composer.
 * Composites the plane body, ground shadow, optional stroke outline,
 * and a red crosshair dot into a single symmetric canvas PixelMap.
 *
 * The canvas is padded equally on all sides so that anchorU/anchorV = 0.5
 * always aligns exactly with the plane's geometric center regardless of rotation.
 */
export class PlaneMarkerIconHelper {
  /**
   * Create a composite plane marker icon.
   * @param ctx          UIContext from the calling component
   * @param targetWidthPx  Desired width in physical pixels (e.g. 175)
   * @param withStroke   Draw a dark outline (needed for terrain map mode)
   */
  static async create(
    ctx: UIContext,
    targetWidthPx: number,
    withStroke: boolean = false
  ): Promise<image.PixelMap | undefined> {
    try {
      const resourceMgr = ctx.getHostContext()?.resourceManager;
      if (!resourceMgr) {
        return undefined;
      }

      const targetHeightPx = Math.round(targetWidthPx * 1.43);
      const shadowOffsetX = Math.round(18 * (targetWidthPx / 175));
      const shadowOffsetY = Math.round(32 * (targetWidthPx / 175));

      const padX = shadowOffsetX + 12;
      const padY = shadowOffsetY + 12;
      const canvasW = targetWidthPx + padX * 2;
      const canvasH = targetHeightPx + padY * 2;
      const planeOffsetX = padX;
      const planeOffsetY = padY;
      const shadowDstX = padX + shadowOffsetX;
      const shadowDstY = padY + shadowOffsetY;

      // 1. Load plane body
      const planeData = await resourceMgr.getMediaContent($r('app.media.b737_800_top_3').id);
      const planeImgSource = image.createImageSource(planeData.buffer);
      const planePm = await planeImgSource.createPixelMap({
        desiredSize: { width: targetWidthPx, height: targetHeightPx }
      });
      const planeBuf = new ArrayBuffer(targetWidthPx * targetHeightPx * 4);
      await planePm.readPixelsToBuffer(planeBuf);
      const planePixels = new Uint8Array(planeBuf);

      // 2. Load ground shadow
      const shadowData = await resourceMgr.getMediaContent($r('app.media.b737_800_top_3_shadow').id);
      const shadowImgSource = image.createImageSource(shadowData.buffer);
      const shadowPm = await shadowImgSource.createPixelMap({
        desiredSize: { width: targetWidthPx, height: targetHeightPx }
      });
      const shadowBuf = new ArrayBuffer(targetWidthPx * targetHeightPx * 4);
      await shadowPm.readPixelsToBuffer(shadowBuf);
      const shadowPixels = new Uint8Array(shadowBuf);

      // 3. Create symmetric composite canvas
      const canvasPm = await planeImgSource.createPixelMap({
        desiredSize: { width: canvasW, height: canvasH }
      });
      const canvasBuf = new ArrayBuffer(canvasW * canvasH * 4);
      const canvasPixels = new Uint8Array(canvasBuf);

      // 4. Render shadow at offset position
      for (let y = 0; y < targetHeightPx; y++) {
        for (let x = 0; x < targetWidthPx; x++) {
          const sIdx = (y * targetWidthPx + x) * 4;
          const sA = shadowPixels[sIdx + 3];
          if (sA > 10) {
            const dstX = x + shadowDstX;
            const dstY = y + shadowDstY;
            if (dstX >= 0 && dstX < canvasW && dstY >= 0 && dstY < canvasH) {
              const dIdx = (dstY * canvasW + dstX) * 4;
              canvasPixels[dIdx] = 12;
              canvasPixels[dIdx + 1] = 16;
              canvasPixels[dIdx + 2] = 24;
              canvasPixels[dIdx + 3] = Math.min(220, Math.round(sA * 1.15));
            }
          }
        }
      }

      // 5a. Terrain map mode: expand pixels outward to create a dark stroke outline
      if (withStroke) {
        const strokeWidth = 8;
        const sR = 18, sG = 22, sB = 42, sA = 220;
        for (let y = 0; y < targetHeightPx; y++) {
          for (let x = 0; x < targetWidthPx; x++) {
            if (planePixels[(y * targetWidthPx + x) * 4 + 3] > 30) {
              for (let dy = -strokeWidth; dy <= strokeWidth; dy++) {
                for (let dx = -strokeWidth; dx <= strokeWidth; dx++) {
                  if (dx * dx + dy * dy > strokeWidth * strokeWidth) { continue; }
                  const nx = x + planeOffsetX + dx;
                  const ny = y + planeOffsetY + dy;
                  if (nx >= 0 && nx < canvasW && ny >= 0 && ny < canvasH) {
                    const nIdx = (ny * canvasW + nx) * 4;
                    if (canvasPixels[nIdx + 3] < sA) {
                      canvasPixels[nIdx] = sR;
                      canvasPixels[nIdx + 1] = sG;
                      canvasPixels[nIdx + 2] = sB;
                      canvasPixels[nIdx + 3] = sA;
                    }
                  }
                }
              }
            }
          }
        }
      }

      // 5b. Composite plane body on top (centered in canvas)
      for (let y = 0; y < targetHeightPx; y++) {
        for (let x = 0; x < targetWidthPx; x++) {
          const pIdx = (y * targetWidthPx + x) * 4;
          const pA = planePixels[pIdx + 3] / 255.0;
          if (pA > 0) {
            const dstX = x + planeOffsetX;
            const dstY = y + planeOffsetY;
            if (dstX >= 0 && dstX < canvasW && dstY >= 0 && dstY < canvasH) {
              const dIdx = (dstY * canvasW + dstX) * 4;
              if (pA >= 0.99) {
                canvasPixels[dIdx] = planePixels[pIdx];
                canvasPixels[dIdx + 1] = planePixels[pIdx + 1];
                canvasPixels[dIdx + 2] = planePixels[pIdx + 2];
                canvasPixels[dIdx + 3] = planePixels[pIdx + 3];
              } else {
                const dstA = canvasPixels[dIdx + 3] / 255.0;
                const outA = pA + dstA * (1.0 - pA);
                if (outA > 0.001) {
                  canvasPixels[dIdx] = Math.round((planePixels[pIdx] * pA + canvasPixels[dIdx] * dstA * (1.0 - pA)) / outA);
                  canvasPixels[dIdx + 1] = Math.round((planePixels[pIdx + 1] * pA + canvasPixels[dIdx + 1] * dstA * (1.0 - pA)) / outA);
                  canvasPixels[dIdx + 2] = Math.round((planePixels[pIdx + 2] * pA + canvasPixels[dIdx + 2] * dstA * (1.0 - pA)) / outA);
                  canvasPixels[dIdx + 3] = Math.round(outA * 255);
                }
              }
            }
          }
        }
      }

      // 6. Red crosshair dot at nose tip
      const cX = planeOffsetX + Math.floor(targetWidthPx / 2);
      const cY = planeOffsetY + Math.floor(targetHeightPx * 0.04);
      const radiusOuter = 10;
      const radiusInner = 6;

      for (let y = cY - radiusOuter; y <= cY + radiusOuter; y++) {
        for (let x = cX - radiusOuter; x <= cX + radiusOuter; x++) {
          if (x >= 0 && x < canvasW && y >= 0 && y < canvasH) {
            const distSq = (x - cX) * (x - cX) + (y - cY) * (y - cY);
            if (distSq <= radiusOuter * radiusOuter) {
              const idx = (y * canvasW + x) * 4;
              if (distSq <= radiusInner * radiusInner) {
                canvasPixels[idx] = 255;
                canvasPixels[idx + 1] = 0;
                canvasPixels[idx + 2] = 0;
                canvasPixels[idx + 3] = 255;
              } else {
                canvasPixels[idx] = 255;
                canvasPixels[idx + 1] = 255;
                canvasPixels[idx + 2] = 255;
                canvasPixels[idx + 3] = 255;
              }
            }
          }
        }
      }

      await canvasPm.writeBufferToPixels(canvasBuf);
      return canvasPm;
    } catch (e) {
      console.error('[PlaneMarkerIconHelper] create failed:', JSON.stringify(e));
      return undefined;
    }
  }
}