package states;

import flixel.FlxSubState;

import flixel.effects.FlxFlicker;
import lime.app.Application;

class FlashingState extends MusicBeatState
{
	public static var leftState:Bool = false;

	var isYes:Bool = true;
	var texts:FlxTypedSpriteGroup<FlxText>;
	var bg:FlxSprite;

	override function create()
	{
		super.create();

		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		add(bg);

		texts = new FlxTypedSpriteGroup<FlxText>();
		texts.alpha = 0.0;
		add(texts);

		var warnText:FlxText = new FlxText(0, 0, FlxG.width,
			"Hey, watch out!\n
			This Mod contains some flashing lights!\n
			Do you wish to disable them?");
		warnText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER);
		warnText.screenCenter(Y);
		texts.add(warnText);

		final keys = ["Yes", "No"];
		for (i in 0...keys.length) {
			final button = new FlxText(0, 0, FlxG.width, keys[i]);
			button.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER);
			button.y = (warnText.y + warnText.height) + 24;
			button.x += (128 * i) - 80;
			texts.add(button);
		}

		FlxTween.tween(texts, {alpha: 1.0}, 0.5, {
			onComplete: (_) -> updateItems()
		});
	}

	override function update(elapsed:Float)
	{
		if (leftState) {
			super.update(elapsed);
			return;
		}

		var back:Bool = controls.BACK;

		if (controls.UI_LEFT_P || controls.UI_RIGHT_P) {
			FlxG.sound.play(Paths.sound("scrollMenu"), 0.7);
			isYes = !isYes;
			updateItems();
		}

		#if mobile
		for (touch in FlxG.touches.justReleased()) {
			// Toque no botão Yes (members[1])
			if (texts.members[1] != null && touch.overlaps(texts.members[1])) {
				isYes = true;
				updateItems();
				confirmSelection();
				return;
			}
			// Toque no botão No (members[2])
			if (texts.members[2] != null && touch.overlaps(texts.members[2])) {
				isYes = false;
				updateItems();
				confirmSelection();
				return;
			}
		}
		#end

		if (controls.ACCEPT || back) {
			if (!back)
				confirmSelection();
			else {
				leftState = true;
				FlxTransitionableState.skipNextTransIn = true;
				FlxTransitionableState.skipNextTransOut = true;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				FlxTween.tween(texts, {alpha: 0}, 1, {
					onComplete: (_) -> MusicBeatState.switchState(new TitleState())
				});
			}
		}

		super.update(elapsed);
	}

	function confirmSelection() {
		leftState = true;
		FlxTransitionableState.skipNextTransIn = true;
		FlxTransitionableState.skipNextTransOut = true;
		ClientPrefs.data.flashing = !isYes;
		ClientPrefs.saveSettings();
		FlxG.sound.play(Paths.sound('confirmMenu'));
		final button = texts.members[isYes ? 1 : 2];
		FlxFlicker.flicker(button, 1, 0.1, false, true, function(flk:FlxFlicker) {
			new FlxTimer().start(0.5, function(tmr:FlxTimer) {
				FlxTween.tween(texts, {alpha: 0}, 0.2, {
					onComplete: (_) -> MusicBeatState.switchState(new TitleState())
				});
			});
		});
	}

	function updateItems() {
		// it's clunky but it works.
		texts.members[1].alpha = isYes ? 1.0 : 0.6;
		texts.members[2].alpha = isYes ? 0.6 : 1.0;
	}
}