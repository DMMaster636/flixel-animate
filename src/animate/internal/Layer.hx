package animate.internal;

import animate.FlxAnimateJson.LayerJson;
import flixel.math.FlxMatrix;
import flixel.math.FlxRect;
import flixel.util.FlxDestroyUtil;

class Layer implements IFlxDestroyable
{
	public var timeline:Null<Timeline>;
	public var frames:Null<Array<Frame>>;
	public var frameCount:Int;
	public var visible:Bool;
	public var name:String;
	public var layerType:LayerType;
	public var parentLayer:Null<Layer>;

	var frameIndices:Null<Array<Int>>;

	public function new(?timeline:Timeline)
	{
		this.frames = [];
		this.frameIndices = [];
		this.visible = true;
		this.timeline = timeline;
		this.frameCount = 0;
		this.name = "";
		this.layerType = NORMAL;
	}

	public function destroy():Void
	{
		parentLayer = null;

		if (frames != null)
		{
			for (frame in frames)
				frame.destroy();
		}

		frames = null;
		frameIndices = null;
	}

	@:allow(animate.internal.Timeline)
	function __loadJson(layer:LayerJson, parent:FlxAnimateFrames, ?map:Map<String, Layer>):Void
	{
		this.name = layer.LN;

		// Set clipped by
		var isMasked:Bool = layer.Clpb != null;
		if (map != null && isMasked)
		{
			parentLayer = map.get(layer.Clpb);
			this.layerType = CLIPPED;

			if (parentLayer == null)
			{
				isMasked = false;
				visible = false;
			}
		}
		else // Set other layer types
		{
			final type:Null<String> = layer.LT;
			this.layerType = type != null ? switch (type)
			{
				case "Clp" | "Clipper": CLIPPER;
				case "Fld" | "Folder": FOLDER;
				default: NORMAL;
			} : NORMAL;
		}

		// Set clipper
		if (this.layerType == CLIPPER)
			visible = false;

		if (this.layerType != FOLDER)
		{
			for (i => frameJson in layer.FR)
			{
				var frame = new Frame(this);
				frame.__loadJson(frameJson, parent);
				frames.push(frame);

				for (_ in 0...frame.duration)
					frameIndices.push(i);
			}
		}

		if (isMasked)
		{
			for (frame in parentLayer.frames)
				setKeyframe(frame.index);

			for (frame in frames)
				frame._dirty = true;
		}

		frameCount = frameIndices.length;
	}

	public function forEachFrame(callback:Frame->Void)
	{
		for (frame in frames)
			callback(frame);
	}

	public function getFrameAtIndex(index:Int):Null<Frame>
	{
		index = Std.int(Math.max(index, 0));
		if (index > frameIndices.length - 1)
			return null;

		var frameIndex = frameIndices[index];
		return frames[frameIndex];
	}

	public function setKeyframe(index:Int)
	{
		var lastFrame = getFrameAtIndex(index);
		if (lastFrame == null || lastFrame.index == index) // already is a keyframe or doesnt exist
			return;

		setBlankKeyframe(index);
		var keyframe = getFrameAtIndex(index);

		keyframe.elements = lastFrame.elements.copy();
		keyframe.name = lastFrame.name;
	}

	public function setBlankKeyframe(index:Int)
	{
		var lastFrame = getFrameAtIndex(index);

		var startIndex = lastFrame.index;
		var startDuration = lastFrame.duration;

		var keyframe = new Frame(this);
		keyframe.index = index;
		keyframe.duration = startDuration - (index - startIndex);

		frames.insert(frames.indexOf(lastFrame) + 1, keyframe);
		for (i in 0...keyframe.duration)
			frameIndices[index + i] = frames.length - 1;
	}

	public function getBounds(frameIndex:Int, ?rect:FlxRect, ?matrix:FlxMatrix):FlxRect
	{
		rect ??= FlxRect.get();
		var frame = getFrameAtIndex(frameIndex);
		if (frame != null)
			return frame.getBounds(rect, matrix);

		if (matrix != null)
			Timeline.applyMatrixToRect(rect, matrix);
		return rect;
	}

	public function toString():String
	{
		return '{name: "$name", frameCount: $frameCount, layerType: $layerType}';
	}
}

enum abstract LayerType(Int) to Int
{
	var NORMAL;
	var CLIPPER;
	var CLIPPED;
	var FOLDER;

	public function toString():String
	{
		return switch (this)
		{
			case CLIPPER: "clipper";
			case CLIPPED: "clipped";
			case FOLDER: "folder";
			case _: "normal";
		}
	}
}
