package;

import debug.FPSCounter;

import flixel.graphics.FlxGraphic;
import flixel.FlxGame;
import flixel.FlxState;
import haxe.io.Path;
import openfl.Assets;
import openfl.Lib;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.display.StageScaleMode;
import lime.app.Application;
import states.TitleState;

#if HSCRIPT_ALLOWED
import crowplexus.iris.Iris;
import psychlua.HScript.HScriptInfos;
#end

#if (linux || mac)
import lime.graphics.Image;
#end

#if desktop
import backend.ALSoftConfig;
#end

#if CRASH_HANDLER
import openfl.events.UncaughtErrorEvent;
import haxe.CallStack;
import haxe.io.Path;
#end

import backend.Highscore;

#if android
import lime.system.JNI;
#end

#if (linux && !debug)
@:cppInclude('./external/gamemode_client.h')
@:cppFileCode('#define GAMEMODE_AUTO')
#end

class Main extends Sprite
{
	public static final game = {
		width: 1280,
		height: 720,
		initialState: TitleState,
		framerate: 60,
		skipSplash: true,
		startFullscreen: false
	};

	public static var fpsVar:FPSCounter;

	/**
	 * Pasta raiz do PsychEngine no external storage do Android.
	 * Exemplo: /storage/emulated/0/Android/data/com.shadowmario.psychengine/files/
	 * Cacheado na primeira chamada.
	 */
	#if android
	static var _externalDir:String = null;
	public static var externalDir(get, never):String;
	static function get_externalDir():String
	{
		if (_externalDir != null) return _externalDir;
		_externalDir = Path.addTrailingSlash(_getExternalStorageDirRaw());
		return _externalDir;
	}
	#end

	public static function main():Void
	{
		Lib.current.addChild(new Main());
	}

	public function new()
	{
		super();

		#if (cpp && windows)
		backend.Native.fixScaling();
		#end

		// ── Mobile storage setup ──────────────────────────────────────
		#if android
		var extDir = externalDir;
		Sys.setCwd(extDir);
		_setupExternalStorage(extDir);   // cria pastas e copia arquivos iniciais
		#elseif ios
		Sys.setCwd(Path.addTrailingSlash(lime.system.System.applicationStorageDirectory));
		#end

		#if VIDEOS_ALLOWED
		hxvlc.util.Handle.init(#if (hxvlc >= "1.8.0") ['--no-lua'] #end);
		#end

		#if LUA_ALLOWED
		Mods.pushGlobalMods();
		#end
		Mods.loadTopMod();

		FlxG.save.bind('funkin', CoolUtil.getSavePath());
		Highscore.load();

		#if HSCRIPT_ALLOWED
		Iris.warn = function(x, ?pos:haxe.PosInfos) {
			Iris.logLevel(WARN, x, pos);
			var newPos:HScriptInfos = cast pos;
			if (newPos.showLine == null) newPos.showLine = true;
			var msgInfo:String = (newPos.funcName != null ? '(${newPos.funcName}) - ' : '') + '${newPos.fileName}:';
			#if LUA_ALLOWED
			if (newPos.isLua == true) { msgInfo += 'HScript:'; newPos.showLine = false; }
			#end
			if (newPos.showLine == true) msgInfo += '${newPos.lineNumber}:';
			msgInfo += ' $x';
			if (PlayState.instance != null)
				PlayState.instance.addTextToDebug('WARNING: $msgInfo', FlxColor.YELLOW);
		}
		Iris.error = function(x, ?pos:haxe.PosInfos) {
			Iris.logLevel(ERROR, x, pos);
			var newPos:HScriptInfos = cast pos;
			if (newPos.showLine == null) newPos.showLine = true;
			var msgInfo:String = (newPos.funcName != null ? '(${newPos.funcName}) - ' : '') + '${newPos.fileName}:';
			#if LUA_ALLOWED
			if (newPos.isLua == true) { msgInfo += 'HScript:'; newPos.showLine = false; }
			#end
			if (newPos.showLine == true) msgInfo += '${newPos.lineNumber}:';
			msgInfo += ' $x';
			if (PlayState.instance != null)
				PlayState.instance.addTextToDebug('ERROR: $msgInfo', FlxColor.RED);
		}
		Iris.fatal = function(x, ?pos:haxe.PosInfos) {
			Iris.logLevel(FATAL, x, pos);
			var newPos:HScriptInfos = cast pos;
			if (newPos.showLine == null) newPos.showLine = true;
			var msgInfo:String = (newPos.funcName != null ? '(${newPos.funcName}) - ' : '') + '${newPos.fileName}:';
			#if LUA_ALLOWED
			if (newPos.isLua == true) { msgInfo += 'HScript:'; newPos.showLine = false; }
			#end
			if (newPos.showLine == true) msgInfo += '${newPos.lineNumber}:';
			msgInfo += ' $x';
			if (PlayState.instance != null)
				PlayState.instance.addTextToDebug('FATAL: $msgInfo', 0xFFBB0000);
		}
		#end

		#if LUA_ALLOWED Lua.set_callbacks_function(cpp.Callable.fromStaticFunction(psychlua.CallbackHandler.call)); #end
		Controls.instance = new Controls();
		ClientPrefs.loadDefaultKeys();
		#if ACHIEVEMENTS_ALLOWED Achievements.load(); #end
		addChild(new FlxGame(game.width, game.height, game.initialState, game.framerate, game.framerate, game.skipSplash, game.startFullscreen));

		#if !mobile
		fpsVar = new FPSCounter(10, 3, 0xFFFFFF);
		addChild(fpsVar);
		Lib.current.stage.align = "tl";
		Lib.current.stage.scaleMode = StageScaleMode.NO_SCALE;
		if (fpsVar != null)
			fpsVar.visible = ClientPrefs.data.showFPS;
		#end

		#if (linux || mac)
		var icon = Image.fromFile("icon.png");
		Lib.current.stage.window.setIcon(icon);
		#end

		#if html5
		FlxG.autoPause = false;
		FlxG.mouse.visible = false;
		#end

		#if mobile
		FlxG.autoPause = false; // evita freeze ao minimizar
		#end

		FlxG.fixedTimestep = false;
		FlxG.game.focusLostFramerate = 60;

		#if !mobile
		FlxG.keys.preventDefaultKeys = [TAB];
		#end

		#if CRASH_HANDLER
		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onCrash);
		#end

		#if DISCORD_ALLOWED
		DiscordClient.prepare();
		#end

		FlxG.signals.gameResized.add(function (w, h) {
			if (FlxG.cameras != null) {
				for (cam in FlxG.cameras.list) {
					if (cam != null && cam.filters != null)
						resetSpriteCache(cam.flashSprite);
				}
			}
			if (FlxG.game != null)
				resetSpriteCache(FlxG.game);
		});
	}

	// ═══════════════════════════════════════════════════════════════════
	//  ANDROID — External Storage
	// ═══════════════════════════════════════════════════════════════════

	#if android
	/**
	 * Retorna o caminho cru do external storage via JNI.
	 * → Context.getExternalFilesDir(null).getAbsolutePath()
	 * Exemplo: /storage/emulated/0/Android/data/com.shadowmario.psychengine/files
	 *
	 * O usuário consegue acessar essa pasta via qualquer gerenciador de
	 * arquivos em Android 5+ sem precisar de root.
	 */
	static function _getExternalStorageDirRaw():String
	{
		try
		{
			var getInstance = JNI.createStaticMethod(
				"org/haxe/lime/GameActivity", "getInstance",
				"()Lorg/haxe/lime/GameActivity;"
			);
			var getExternalFilesDir = JNI.createMemberMethod(
				"android/app/Activity", "getExternalFilesDir",
				"(Ljava/lang/String;)Ljava/io/File;"
			);
			var getAbsolutePath = JNI.createMemberMethod(
				"java/io/File", "getAbsolutePath",
				"()Ljava/lang/String;"
			);
			var path:String = getAbsolutePath(getExternalFilesDir(getInstance(), null));
			if (path != null && path.length > 0)
				return path;
		}
		catch (e:Dynamic)
		{
			trace('[Main] JNI getExternalStorageDir failed: $e — using internal storage');
		}
		return lime.system.System.applicationStorageDirectory;
	}

	/**
	 * Garante que a estrutura de pastas do PsychEngine existe no
	 * external storage e copia os arquivos iniciais (assets embarcados
	 * e mods de exemplo) se ainda não foram copiados.
	 *
	 * Pastas criadas em <externalDir>/:
	 *   assets/       → assets embarcados (fonts, shared, songs, etc.)
	 *   mods/         → pasta de mods do usuário
	 *   crash/        → logs de crash
	 *   modsList.txt  → lista de mods ativos (gerada se ausente)
	 *
	 * Detecção de "primeira vez": verifica o arquivo ".initialized"
	 * dentro do external storage. Se não existir, copia tudo e o cria.
	 * Isso evita re-copiar a cada abertura do app.
	 */
	static function _setupExternalStorage(extDir:String):Void
	{
		// Cria as pastas essenciais (FileSystem.createDirectory é no-op se já existir)
		for (folder in ['assets', 'mods', 'crash'])
		{
			var p = extDir + folder;
			if (!FileSystem.exists(p))
			{
				try { FileSystem.createDirectory(p); }
				catch (e:Dynamic) trace('[Main] mkdir $p failed: $e');
			}
		}

		// modsList.txt — gerado com conteúdo vazio se não existir
		var modsListPath = extDir + 'modsList.txt';
		if (!FileSystem.exists(modsListPath))
		{
			try { File.saveContent(modsListPath, ''); }
			catch (e:Dynamic) trace('[Main] modsList.txt create failed: $e');
		}

		// Verifica se os assets já foram copiados nessa instalação
		var initFlag = extDir + '.initialized';
		if (FileSystem.exists(initFlag)) return; // já foi feito antes

		// ── Copia assets embarcados para o external ───────────────────
		// Os assets ficam no APK como OpenFL embedded assets.
		// Copiá-los para o external permite que mods os sobrescrevam
		// em runtime, já que Paths.hx busca lá primeiro.
		_copyEmbeddedAssets(extDir);

		// ── Marca como inicializado ───────────────────────────────────
		try { File.saveContent(initFlag, Date.now().toString()); }
		catch (e:Dynamic) trace('[Main] .initialized create failed: $e');

		trace('[Main] External storage setup complete at: $extDir');
	}

	/**
	 * Copia todos os assets OpenFL embarcados para o external storage.
	 * Apenas arquivos que ainda não existem no destino são copiados
	 * (preserva modificações do usuário em re-instalações).
	 *
	 * A cópia inclui:
	 *   assets/fonts, assets/shared, assets/songs, assets/week_assets,
	 *   assets/embed, assets/videos (se VIDEOS_ALLOWED), etc.
	 */
	static function _copyEmbeddedAssets(extDir:String):Void
	{
		var list:Array<String>;
		try { list = openfl.Assets.list(); }
		catch (e:Dynamic) { trace('[Main] Assets.list() failed: $e'); return; }

		for (assetId in list)
		{
			// Apenas assets do tipo TEXT, BINARY, SOUND, IMAGE, etc.
			// O id já é o path relativo: "assets/shared/images/..."
			var destPath = extDir + assetId;
			if (FileSystem.exists(destPath)) continue; // não sobrescreve

			// Garante que o diretório pai existe
			var dir = Path.directory(destPath);
			if (!FileSystem.exists(dir))
			{
				try { FileSystem.createDirectory(dir); }
				catch (e:Dynamic) { trace('[Main] mkdir $dir failed: $e'); continue; }
			}

			// Copia o conteúdo binário
			try
			{
				var bytes = openfl.Assets.getBytes(assetId);
				if (bytes != null)
					File.saveBytes(destPath, bytes);
			}
			catch (e:Dynamic)
			{
				trace('[Main] copy $assetId failed: $e');
			}
		}
	}
	#end // android

	// ═══════════════════════════════════════════════════════════════════
	//  Utilitários
	// ═══════════════════════════════════════════════════════════════════

	static function resetSpriteCache(sprite:Sprite):Void {
		@:privateAccess {
			sprite.__cacheBitmap = null;
			sprite.__cacheBitmapData = null;
		}
	}

	// ═══════════════════════════════════════════════════════════════════
	//  Crash Handler
	// ═══════════════════════════════════════════════════════════════════

	#if CRASH_HANDLER
	function onCrash(e:UncaughtErrorEvent):Void
	{
		var errMsg:String = "";
		var path:String;
		var callStack:Array<StackItem> = CallStack.exceptionStack(true);
		var dateNow:String = Date.now().toString();

		dateNow = dateNow.replace(" ", "_");
		dateNow = dateNow.replace(":", "'");

		#if android
		var crashDir:String = externalDir + "crash/";
		#elseif mobile
		var crashDir:String = Path.addTrailingSlash(lime.system.System.applicationStorageDirectory) + "crash/";
		#else
		var crashDir:String = "./crash/";
		#end
		path = crashDir + "PsychEngine_" + dateNow + ".txt";

		for (stackItem in callStack)
		{
			switch (stackItem)
			{
				case FilePos(s, file, line, column):
					errMsg += file + " (line " + line + ")\n";
				default:
					Sys.println(stackItem);
			}
		}

		errMsg += "\nUncaught Error: " + e.error;
		#if officialBuild
		errMsg += "\nPlease report this error to the GitHub page: https://github.com/ShadowMario/FNF-PsychEngine";
		#end
		errMsg += "\n\n> Crash Handler written by: sqirra-rng";

		if (!FileSystem.exists(crashDir))
			FileSystem.createDirectory(crashDir);

		File.saveContent(path, errMsg + "\n");

		Sys.println(errMsg);
		Sys.println("Crash dump saved in " + Path.normalize(path));

		Application.current.window.alert(errMsg, "Error!");
		#if DISCORD_ALLOWED
		DiscordClient.shutdown();
		#end
		Sys.exit(1);
	}
	#end
}