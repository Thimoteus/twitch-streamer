#/#/#/#/#/#/#/#/#/#/#/#/
#/#/#/#/#/#/#/#/#/#/#/#/
# twitch streamer
# version: 0.2.0
# maintainer: thimoteus
# site: github.com/Thimoteus
#/#/#/#/#/#/#/#/#/#/#/#/
#/#/#/#/#/#/#/#/#/#/#/#/

#######################
# 1. dependencies
#######################
gui = require('nw.gui')
fse = require('fs-extra')
sys = require('sys')
exec = require('child_process').exec
spawn = require('child_process').spawn
sh = require('shelljs')
win = gui.Window.get()

######################################
# 2. variables, important strings, etc
######################################
$STREAMING = $MAXIMIZED = $SIDEBAR_OPEN = no
$PID = $STREAM_CMD_ARGS = empty = ""
$CONFIG_FILE = {
   "output_res": "640x360",
   "fps": "24",
   "quality": "veryfast",
   "stream_url": "rtmp://live.twitch.tv/app",
   "max_rate": "1000k",
   "buf_size": "1000k",
   "audio_bit_rate": "60k"
}
$STREAM_CMD = (input_res, output_res, fps, audio_bit_rate, qual, max_rate, buf_size, url) ->
   [
      "-v", "verbose",
      "-f", "x11grab",
      "-show_region", "1",
      "-s", input_res,
      "-r", fps,
      "-i", ":0.0",
      "-f", "alsa",
      "-ac", "2",
      "-b:a", audio_bit_rate,
      "-i", "pulse",
      "-c:v", "libx264",
      "-crf", "30",
      "-preset", qual,
      "-s", output_res,
      "-vol", "11200",
      "-c:a", "libmp3lame",
      "-ar", "44100",
      "-pix_fmt", "yuv420p",
      "-maxrate", max_rate,
      "-bufsize", buf_size,
      "-f", "flv",
      url
   ]

#######################
# 3. helper functions
#######################
print = (x) -> process.stdout.write x # DO NOT USE FOR DEBUGGING

puts = (err, stdout, stderr) -> sys.puts(stdout)
cmd = (command) -> exec(command, puts)

# Cantor = (x,y) ->
#    (Math.pow(x+y,2)+x+3*y)/2
#
# InverseCantor = (z) ->
#    w = Math.floor((Math.sqrt(8*z+1)-1)/2)
#    t = (Math.pow(w,2)+w)/2
#    y = z - t
#    [w - y, y]

formDataToJson = (form, fn, json={}, callback) ->
   # function that turns a form's input into a json object
   # fn is a function that can act on the json object
   # callback is optional
   $(form).on("submit", (evt) ->
         evt.preventDefault()
         data = $(this).serializeArray()
         for obj in data
            key = obj["name"]
            value = obj["value"]
            json[key] = value
         fn json
         callback?()
      )

openLinkInDefaultBrowser = (a) ->
   # instead of opening "a" elements in this app,
   # open them in the system's default browser
   $(a).click( ->
         link = "http://" + $(this).text()
         gui.Shell.openExternal(link)
      )

switchSections = (sec1, sec2) ->
   $(sec1).addClass("ninja")
   $(sec2).removeClass("ninja")

writeJsonToLocalStorage = (json) ->
   for key of json
      localStorage[key] = json[key]

switchStream = (bool, args = "") ->
   if bool
      if args is empty
         print "Error, will not be able to start streaming. " +
            "No arguments were given to the stream command.\n"
         return
      stream = spawn("avconv", args)
      stream.stderr.on( 'data', (data) ->
            console.log "STDERR: #{data}"
         )
      $PID = stream.pid
      print "avconv started with process id #{$PID}\n"
      stream.stdin.end()
      # change icon
      $(".stream").removeClass("fa-play").addClass("fa-stop")
      return true
   else if $PID isnt empty
      cmd("kill #{$PID}")
      print "avconv process #{$PID} killed\n"
      $PID = empty
      # change icon
      $(".stream").removeClass("fa-stop").addClass("fa-play")
      return false
   else
      console.log "Error: PID is not properly defined."

openSidebar = (name) ->
   $(name).removeClass("ninja")
   $("#sidebar").stop().animate({"left": 0}, 200)
   $SIDEBAR_OPEN = true
closeSidebar = ->
   $('#sidebar').stop().animate({"left": -250},200, ->
         $('#sidebar>*').addClass("ninja")
      )
   $SIDEBAR_OPEN = false
toggleSidebar = ->
   if $SIDEBAR_OPEN
      closeSidebar()
      # for smoother, fake animation
      setTimeout( (-> $("#settings_button").removeClass("lightbg")), 140)
   else
      openSidebar("#settings")
      $("#settings_button").addClass("lightbg")
#######################
# 4. MEAT AND POTATOES!
#######################
initWindowControls = ->
   # handles maximizing and closing the window
   win = gui.Window.get()
   # closes the window
   closeWindow = ->
      win.on("close", ->
            this.hide()
            print "closing ... \n"
            this.close(true)
            if $PID isnt empty
               switchStream(off)
         )
      win.close()
   # maximizes window
   maximizeWindow = ->
      if $MAXIMIZED
         win.unmaximize()
         $MAXIMIZED = false
      else
         win.maximize()
         $MAXIMIZED = true
   $("#close").on( "click", -> closeWindow() )
   $("#maximize").on( "click", -> maximizeWindow() )
   $("#inspect").on( "click", -> win.showDevTools() )

init = ->
   # checks to see if avconv is installed
   if not sh.which "avconv"
      avconvNotInstalled = "<p><code>avconv</code> not detected. You must have it installed.</p>" +
         "<p>Ubuntu users can get it by running " +
         "<code>sudo apt-get install libav-tools</code>."
      errorPage("#loading", avconvNotInstalled)
      return
   # checks to see if config file exists and is readable.
   # if it is, go straight to the streaming
   if localStorage["twitch_key"]? and localStorage["input_res"]?
      $("#loading").addClass("ninja")
      bypassFirstRunPage(localStorage)
      print "bypassing first run page\n"
   else
      firstRunPage()
      print "going to first run page\n"

errorPage = (section, text) ->
   switchSections(section, "#error")
   $("#error").html(text)

bypassFirstRunPage = (cfg = $CONFIG_FILE) ->
   # call this when you don't need the user's screen resolution
   # or twitch key
   $("#settings_button").removeClass("ninja")
   switchSections("#first_run", "#streamer")
   streamerPage(cfg)

firstRunFormHandler = (fn) ->
   # fn is a callback
   if fn?
      formDataToJson("#first_run_form", writeJsonToLocalStorage, $CONFIG_FILE, fn)
   else
      formDataToJson("#first_run_form", writeJsonToLocalStorage, $CONFIG_FILE)

settingsFormHandler = (cfg) ->
   formDataToJson("#settings_form", writeJsonToLocalStorage, cfg)
   $("#settings_form").on( "submit", (evt) ->
         $(".settings_saved")
            .css({"opacity": 1})
            .removeClass("ninja")
            .stop()
            .animate({"opacity": 0}, 1000)
      )

firstRunPage = ->
   # what to do on the "first run" page
   # so far, we only need to deal with the form
   # and then pass bypassFirstRunPage as a callback to execute
   # once the form has been submitted.

   # show the page
   switchSections("#loading", "#first_run")
   # get screen height and width
   $CONFIG_FILE["input_res"] = window.screen.width + "x" + window.screen.height
   $(".screen_res").text($CONFIG_FILE["input_res"])
   openLinkInDefaultBrowser("#stream_key_link")
   firstRunFormHandler(bypassFirstRunPage)

settingsPage = (cfg) ->
   # called when the settings page is loaded
   # populates the form with settings loaded from
   # the cfg object
   t = "settings_"
   for ext in ["twitch_key", "input_res", "output_res", "fps"]
      text = t+ext
      $("#"+text).val(cfg[ext])
   for option in $("#settings_quality option")
      if $(option).val() is cfg["quality"]
         $(option).prop("selected","selected")
   settingsFormHandler(cfg)

streamerPage = (cfg) ->
   # called when the streamer page is loaded

   # only allow settings to be opened if
   # we can already stream
   $("#settings_button").click( (evt) ->
         evt.preventDefault()
         toggleSidebar()
         settingsPage(cfg)
      )
   $STREAM_CMD_ARGS = $STREAM_CMD(
      cfg["input_res"],
      cfg["output_res"],
      cfg["fps"],
      cfg["audio_bit_rate"],
      cfg["quality"],
      cfg["max_rate"],
      cfg["buf_size"],
      cfg["stream_url"]+cfg["twitch_key"]
      )
   $(".stream").on( "click", (evt) ->
         $STREAMING = switchStream(not $STREAMING, $STREAM_CMD_ARGS)
      )

#######################
# 5. init
#######################
$ ->
   initWindowControls()
   init()
