package animate.internal.elements;

import animate.FlxAnimateJson;
import animate.internal.elements.Element;
import animate.internal.filters.*;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxFrame;
import flixel.math.FlxMath;
import flixel.math.FlxMatrix;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.system.FlxAssets.FlxShader;
import flixel.util.FlxColor;
import flixel.util.FlxDestroyUtil;
import flixel.util.FlxSignal;
import haxe.ds.Vector;
import openfl.display.BlendMode;
import openfl.display.Timeline;
import openfl.filters.BitmapFilter;
import openfl.filters.BlurFilter;
import openfl.geom.ColorTransform;

using flixel.util.FlxColorTransformUtil;

@:access(openfl.geom.Point)
@:access(openfl.geom.Matrix)
@:access(flixel.FlxCamera)
@:access(flixel.graphics.frames.FlxFrame)
class AtlasInstance extends AnimateElement<AtlasInstanceJson>
{
	public var frame:FlxFrame;

	public function new(?data:AtlasInstanceJson, ?parent:FlxAnimateFrames, ?frame:Frame)
	{
		super(data, parent);
		isSymbolInstance = false;
		if (data != null)
		{
			this.frame = parent.getByName(data.N);
			this.matrix = data.MX.toMatrix();

			#if flash
			// FlxFrame.paint doesnt work for rotated frames lol
			var bitmap = this.frame.checkInputBitmap(null, null, this.frame.angle);
			var mat = this.frame.prepareBlitMatrix(FlxFrame._matrix, true);
			bitmap.draw(this.frame.parent.bitmap, mat, null, null, this.frame.getDrawFrameRect(mat, FlxFrame._rect));
			this.frame = FlxGraphic.fromBitmapData(bitmap).imageFrame.frame;
			#else
			// new flixel broke the tileMatrix on hashlink, gotta manually do this shit
			// TODO: remove this when it gets fixed on flixel 6.1.1 or something
			var mat = this.frame.prepareBlitMatrix(FlxFrame._matrix, false);
			var tileMatrix:Vector<Float> = cast this.frame.tileMatrix;
			tileMatrix[0] = mat.a;
			tileMatrix[1] = mat.b;
			tileMatrix[2] = mat.c;
			tileMatrix[3] = mat.d;
			tileMatrix[4] = mat.tx;
			tileMatrix[5] = mat.ty;
			#end
		}
	}

	public function replaceFrame(frame:FlxFrame, adjustScale:Bool = true):Void
	{
		var copyFrame = frame.copyTo();

		// Scale adjustment
		if (adjustScale)
		{
			var lastFrame = this.frame;
			var tileMatrix:Vector<Float> = cast copyFrame.tileMatrix; // need to cast because of newer flixel
			tileMatrix[0] = lastFrame.frame.width / frame.frame.width;
			tileMatrix[3] = lastFrame.frame.height / frame.frame.height;
		}

		this.frame = copyFrame;
	}

	override function destroy():Void
	{
		super.destroy();
		frame = null;
	}

	override function draw(camera:FlxCamera, index:Int, tlFrame:Frame, parentMatrix:FlxMatrix, ?transform:ColorTransform, ?blend:BlendMode,
			?antialiasing:Bool, ?shader:FlxShader):Void
	{
		if (frame == null) // should add a warn here
			return;

		frame.prepareMatrix(_mat);
		_mat.concat(matrix);
		_mat.concat(parentMatrix);

		if (!isOnScreen(camera, _mat))
			return;

		#if flash
		drawPixelsFlash(camera, _mat, transform, blend, antialiasing);
		#else
		camera.drawPixels(frame, null, _mat, transform, blend, antialiasing, shader);
		#end

		#if FLX_DEBUG
		if (FlxG.debugger.drawDebug)
			drawBoundingBox(camera, _bounds);
		#end
	}

	#if flash
	@:access(flixel.FlxCamera)
	function drawPixelsFlash(cam:FlxCamera, matrix:FlxMatrix, ?transform:ColorTransform, ?blend:BlendMode, ?antialiasing:Bool):Void
	{
		var smooth:Bool = (cam.antialiasing || antialiasing);
		cam._helperMatrix.copyFrom(matrix);

		if (cam._useBlitMatrix)
		{
			cam._helperMatrix.concat(cam._blitMatrix);
			cam.buffer.draw(frame.parent.bitmap, cam._helperMatrix, transform, blend, null, smooth);
		}
		else
		{
			cam._helperMatrix.translate(-cam.viewMarginLeft, -cam.viewMarginTop);
			cam.buffer.draw(frame.parent.bitmap, cam._helperMatrix, transform, blend, null, smooth);
		}
	}
	#end

	@:allow(animate.internal.FilterRenderer)
	private static var __skipIsOnScreen:Bool = false;

	var _bounds:FlxRect = FlxRect.get();

	public function isOnScreen(camera:FlxCamera, matrix:FlxMatrix):Bool
	{
		if (__skipIsOnScreen)
			return true;

		var bounds = _bounds.set(0, 0, frame.frame.width, frame.frame.height);
		Timeline.applyMatrixToRect(bounds, matrix);

		return camera.containsRect(bounds);
	}

	override function getBounds(?rect:FlxRect, ?matrix:FlxMatrix):FlxRect
	{
		var rect = super.getBounds(rect);
		rect.set(0, 0, frame.frame.width, frame.frame.height);

		Timeline.applyMatrixToRect(rect, frame.prepareMatrix(_mat));
		Timeline.applyMatrixToRect(rect, this.matrix);
		if (matrix != null)
			Timeline.applyMatrixToRect(rect, matrix);

		return rect;
	}

	#if (FLX_DEBUG && flash)
	static final __fillRect = new openfl.geom.Rectangle();
	#end

	#if FLX_DEBUG
	public static function drawBoundingBox(camera:FlxCamera, bounds:FlxRect, ?color:FlxColor = FlxColor.BLUE):Void
	{
		#if flash
		var cBounds = camera.transformRect(bounds.copyTo(FlxRect.get()));
		FlxG.signals.postDraw.addOnce(() ->
		{
			var buffer = FlxG.camera.buffer;
			__fillRect.setTo(cBounds.x, cBounds.y, cBounds.width, 1);
			buffer.fillRect(__fillRect, color);
			__fillRect.setTo(cBounds.x, cBounds.y + cBounds.height - 1, cBounds.width, 1);
			buffer.fillRect(__fillRect, color);
			__fillRect.setTo(cBounds.x, cBounds.y, 1, cBounds.height);
			buffer.fillRect(__fillRect, color);
			__fillRect.setTo(cBounds.x + cBounds.width - 1, cBounds.y, 1, cBounds.height);
			buffer.fillRect(__fillRect, color);
			cBounds.put();
		});
		#else
		var gfx = camera.debugLayer.graphics;
		gfx.lineStyle(1, color, 0.75);
		gfx.drawRect(bounds.x + 0.5, bounds.y + 0.5, bounds.width - 1.0, bounds.height - 1.0);
		#end
	}
	#end

	public function toString():String
	{
		return '{frame: ${frame.name}, matrix: $matrix}';
	}
}
