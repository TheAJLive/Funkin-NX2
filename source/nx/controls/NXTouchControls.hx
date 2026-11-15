package nx.controls;

#if switch
import flixel.FlxG;
import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import funkin.Preferences;
import funkin.input.PreciseInputManager;
import funkin.play.PlayState;
import funkin.play.notes.NoteDirection;
import haxe.Int64;

@:cppFileCode('
#include <SDL2/SDL.h>
static int nx_touchLaneMask()
{
  int mask = 0;
  for (int device = 0; device < SDL_GetNumTouchDevices(); ++device)
  {
    SDL_TouchID id = SDL_GetTouchDevice(device);
    for (int i = 0; i < SDL_GetNumTouchFingers(id); ++i)
    {
      SDL_Finger *finger = SDL_GetTouchFinger(id, i);
      if (!finger || finger->x < 0 || finger->x > 1) continue;
      int lane = (int)(finger->x * 4);
      if (lane > 3) lane = 3;
      mask |= 1 << lane;
    }
  }
  return mask;
}
')
class NXTouchControls extends FlxGroup
{
  public static var laneMask(default, null):Int = 0;
  static var owner:PlayState;
  static final DIRECTIONS:Array<NoteDirection> = [LEFT, DOWN, UP, RIGHT];
  static inline final KEY_BASE:Int = 0x10000;
  var touchCamera:FlxCamera;
  var panels:Array<FlxSprite> = [];

  public static function isTouchKey(keyCode:Int):Bool
  {
    return keyCode >= KEY_BASE && keyCode < KEY_BASE + 4;
  }

  public static function enabled():Bool
  {
    var state = PlayState.instance;
    return Preferences.switchTouchControls && state != null && state.subState == null
      && !state.isInCutscene && !state.isPlayerDying && !state.isSongEnd
      && nx.NXMain.appState == APP_IN_FOCUS;
  }

  public static function releaseTouches(released:Null<(NoteDirection, Int64, Int)->Void>):Void
  {
    var timestamp = PreciseInputManager.getCurrentTimestamp();
    for (lane in 0...4)
      if ((laneMask & (1 << lane)) != 0 && released != null)
        released(DIRECTIONS[lane], timestamp, KEY_BASE + lane);
    laneMask = 0;
  }

  public static function poll(pressed:Null<(NoteDirection, Int64, Int)->Void>, released:Null<(NoteDirection, Int64, Int)->Void>):Void
  {
    if (owner != PlayState.instance)
    {
      releaseTouches(released);
      owner = PlayState.instance;
    }
    var next:Int = enabled() ? untyped __cpp__('nx_touchLaneMask()') : 0;
    var timestamp = PreciseInputManager.getCurrentTimestamp();
    for (lane in 0...4)
    {
      var bit = 1 << lane;
      if ((next & bit) != 0 && (laneMask & bit) == 0 && pressed != null)
        pressed(DIRECTIONS[lane], timestamp, KEY_BASE + lane);
      if ((next & bit) == 0 && (laneMask & bit) != 0 && released != null)
        released(DIRECTIONS[lane], timestamp, KEY_BASE + lane);
    }
    laneMask = next;
  }

  public function new()
  {
    super();
    touchCamera = new FlxCamera();
    touchCamera.bgColor = 0;
    FlxG.cameras.add(touchCamera, false);
    var colors = [0xFFC24B99, 0xFF00FFFF, 0xFF12FA05, 0xFFF9393F];
    var labels = ['LEFT', 'DOWN', 'UP', 'RIGHT'];
    var width = Std.int(FlxG.width / 4);
    for (lane in 0...4)
    {
      var panel = new FlxSprite(lane * width, 0).makeGraphic(width, FlxG.height, colors[lane]);
      panel.cameras = [touchCamera];
      panel.scrollFactor.set();
      panels.push(panel);
      add(panel);
      var label = new FlxText(lane * width, FlxG.height - 55, width, labels[lane], 24);
      label.setFormat(funkin.Paths.font('vcr.ttf'), 24, colors[lane], CENTER, OUTLINE, 0xFF000000);
      label.cameras = [touchCamera];
      label.scrollFactor.set();
      add(label);
    }
    update(0);
  }

  override public function update(elapsed:Float):Void
  {
    super.update(elapsed);
    visible = enabled();
    for (lane in 0...4)
      panels[lane].alpha = (laneMask & (1 << lane)) != 0 ? 0.18 : 0.025;
  }

  override public function draw():Void
  {
    if (enabled()) super.draw();
  }

  override public function destroy():Void
  {
    FlxG.cameras.remove(touchCamera, true);
    super.destroy();
  }
}
#end
