(function() {
  var $CONFIG_FILE, $MAXIMIZED, $PID, $STREAMING, $STREAM_CMD, $STREAM_CMD_ARGS, bypassFirstRunPage, cmd, empty, errorPage, exec, firstRunFormHandler, firstRunPage, formDataToJson, fse, gui, init, initWindowControls, openLinkInDefaultBrowser, print, puts, settingsFormHandler, settingsPage, sh, spawn, streamerPage, switchSections, switchStream, sys, writeJsonToLocalStorage;

  gui = require('nw.gui');

  fse = require('fs-extra');

  sys = require('sys');

  exec = require('child_process').exec;

  spawn = require('child_process').spawn;

  sh = require('shelljs');

  $STREAMING = $MAXIMIZED = false;

  $PID = $STREAM_CMD_ARGS = empty = "";

  $CONFIG_FILE = {
    "output_res": "640x360",
    "fps": "24",
    "quality": "veryfast",
    "stream_url": "rtmp://live.twitch.tv/app/",
    "max_rate": "1000k",
    "buf_size": "1000k",
    "audio_bit_rate": "60k"
  };

  $STREAM_CMD = function(input_res, output_res, fps, audio_bit_rate, qual, max_rate, buf_size, url) {
    return ["-v", "verbose", "-f", "x11grab", "-show_region", "1", "-s", input_res, "-r", fps, "-i", ":0.0", "-f", "alsa", "-ac", "2", "-b:a", audio_bit_rate, "-i", "pulse", "-c:v", "libx264", "-crf", "30", "-preset", qual, "-s", output_res, "-vol", "11200", "-c:a", "libmp3lame", "-ar", "44100", "-pix_fmt", "yuv420p", "-maxrate", max_rate, "-bufsize", buf_size, "-f", "flv", url];
  };

  print = function(x) {
    return process.stdout.write(x);
  };

  puts = function(err, stdout, stderr) {
    return sys.puts(stdout);
  };

  cmd = function(command) {
    return exec(command, puts);
  };

  formDataToJson = function(form, fn, json, callback) {
    if (json == null) {
      json = {};
    }
    return $(form).on("submit", function(evt) {
      var data, key, obj, value, _i, _len;
      evt.preventDefault();
      data = $(this).serializeArray();
      for (_i = 0, _len = data.length; _i < _len; _i++) {
        obj = data[_i];
        key = obj["name"];
        value = obj["value"];
        json[key] = value;
      }
      fn(json);
      return typeof callback === "function" ? callback() : void 0;
    });
  };

  openLinkInDefaultBrowser = function(a) {
    return $(a).click(function() {
      var link;
      link = "http://" + $(this).text();
      return gui.Shell.openExternal(link);
    });
  };

  switchSections = function(sec1, sec2) {
    $(sec1).addClass("ninja");
    return $(sec2).removeClass("ninja");
  };

  writeJsonToLocalStorage = function(json) {
    var key, _results;
    _results = [];
    for (key in json) {
      _results.push(localStorage[key] = json[key]);
    }
    return _results;
  };

  switchStream = function(bool, args) {
    var stream;
    if (args == null) {
      args = "";
    }
    if (bool) {
      if (args === empty) {
        print("Error, will not be able to start streaming. " + "No arguments were given to the stream command.\n");
        return;
      }
      stream = spawn("avconv", args);
      $PID = stream.pid;
      print("avconv started with process id " + $PID + "\n");
      stream.stdin.end();
      $("button.stream").text("Stop streaming!");
      return true;
    } else if ($PID !== empty) {
      cmd("kill " + $PID);
      print("avconv process " + $PID + " killed\n");
      $PID = empty;
      $("button.stream").text("Stream!");
      return false;
    } else {
      return console.log("Error: PID is not properly defined.");
    }
  };

  initWindowControls = function() {
    var closeWindow, maximizeWindow, win;
    win = gui.Window.get();
    closeWindow = function() {
      win.on("close", function() {
        this.hide();
        print("closing ... \n");
        this.close(true);
        if ($PID !== empty) {
          return switchStream(false);
        }
      });
      return win.close();
    };
    maximizeWindow = function() {
      if ($MAXIMIZED) {
        win.unmaximize();
        return $MAXIMIZED = false;
      } else {
        win.maximize();
        return $MAXIMIZED = true;
      }
    };
    $("#close").on("click", function() {
      return closeWindow();
    });
    return $("#maximize").on("click", function() {
      return maximizeWindow();
    });
  };

  init = function() {
    var avconvNotInstalled;
    if (!sh.which("avconv")) {
      avconvNotInstalled = "<p><code>avconv</code> not detected. You must have it installed.</p>" + "<p>Ubuntu users can get it by running " + "<code>sudo apt-get install libav-tools</code>.";
      errorPage("#loading", avconvNotInstalled);
      return;
    }
    if ((localStorage["twitch_key"] != null) && (localStorage["input_res"] != null)) {
      $("#loading").addClass("ninja");
      bypassFirstRunPage(localStorage);
      return print("bypassing first run page\n");
    } else {
      firstRunPage();
      return print("going to first run page\n");
    }
  };

  errorPage = function(section, text) {
    switchSections(section, "#error");
    return $("#error").html(text);
  };

  bypassFirstRunPage = function(cfg) {
    if (cfg == null) {
      cfg = $CONFIG_FILE;
    }
    switchSections("#first_run", "#streamer");
    return streamerPage(cfg);
  };

  firstRunFormHandler = function(fn) {
    if (fn != null) {
      return formDataToJson("#first_run_form", writeJsonToLocalStorage, $CONFIG_FILE, fn);
    } else {
      return formDataToJson("#first_run_form", writeJsonToLocalStorage, $CONFIG_FILE);
    }
  };

  settingsFormHandler = function(cfg) {
    formDataToJson("#settings_form", writeJsonToLocalStorage, cfg);
    return $("#settings_form").on("submit", function(evt) {
      return switchSections("#settings", "#streamer");
    });
  };

  firstRunPage = function() {
    switchSections("#loading", "#first_run");
    $CONFIG_FILE["input_res"] = window.screen.width + "x" + window.screen.height;
    $(".screen_res").text($CONFIG_FILE["input_res"]);
    openLinkInDefaultBrowser("#stream_key_link");
    return firstRunFormHandler(bypassFirstRunPage);
  };

  settingsPage = function(cfg) {
    var ext, option, t, text, _i, _j, _len, _len1, _ref, _ref1;
    t = "settings_";
    _ref = ["twitch_key", "input_res", "output_res", "fps"];
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      ext = _ref[_i];
      text = t + ext;
      $("#" + text).val(cfg[ext]);
    }
    _ref1 = $("#settings_quality option");
    for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
      option = _ref1[_j];
      if ($(option).val() === cfg["quality"]) {
        $(option).prop("selected", "selected");
      }
    }
    return settingsFormHandler(cfg);
  };

  streamerPage = function(cfg) {
    $(".settings_link").click(function(evt) {
      evt.preventDefault();
      switchSections("#streamer", "#settings");
      return settingsPage(cfg);
    });
    $STREAM_CMD_ARGS = $STREAM_CMD(cfg["input_res"], cfg["output_res"], cfg["fps"], cfg["audio_bit_rate"], cfg["quality"], cfg["max_rate"], cfg["buf_size"], cfg["stream_url"] + cfg["twitch_key"]);
    return $(".stream").on("click", function(evt) {
      return $STREAMING = switchStream(!$STREAMING, $STREAM_CMD_ARGS);
    });
  };

  $(function() {
    initWindowControls();
    return init();
  });

}).call(this);
