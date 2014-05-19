#/#/#/#/#/#/#/#/#/#/#/#/
#/#/#/#/#/#/#/#/#/#/#/#/
# twitch streamer
# version: 0.1
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

######################################
# 2. variables, important strings, etc
######################################
$STREAMING = $MAXIMIZED = no
$PID = $STREAM_CMD_ARGS = empty = ""
$CONFIG_FILE = {
   "output_res": "640x360",
   "fps": "24",
   "quality": "veryfast",
   "stream_url": "rtmp://live.twitch.tv/app/",
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
      $PID = stream.pid
      print "avconv started with process id #{$PID}\n"
      stream.stdin.end()
      # change button text
      $("button.stream").text("Stop streaming!")
      # # shows exactly what command was run
      # text = "avconv "
      # for args in args
      #    text += args + " "
      # print text+"\n"
      return true
   else if $PID isnt empty
      cmd("kill #{$PID}")
      print "avconv process #{$PID} killed\n"
      $PID = empty
      # change button text
      $("button.stream").text("Stream!")
      return false
   else
      console.log "Error: PID is not properly defined."

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
   maximizeWindow = ->
      if $MAXIMIZED
         win.unmaximize()
         $MAXIMIZED = false
      else
         win.maximize()
         $MAXIMIZED = true
   $("#close").on( "click", ->
         closeWindow()
      )
   $("#maximize").on( "click", -> maximizeWindow() )

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
   $("#settings_form").on("submit", (evt) ->
         switchSections("#settings", "#streamer")
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
   $(".settings_link").click( (evt) ->
         evt.preventDefault()
         switchSections("#streamer", "#settings")
         settingsPage(cfg)
      )
   # input_res, output_res, fps, audio_bit_rate, quality, max_rate, buf_size, stream_url
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
