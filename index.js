const path = require('path');

const execa = require('execa');
const tmp = require('tmp');

// TODO: log in production with proces.env.DEBUG_APERTURE
function log(...msgs) {
  if (process.env.DEBUG) {
    console.log(...msgs);
  }
}

class Aperture {
  getAudioSources() {
    return execa(path.join(__dirname, 'swift', 'main'), ['list-audio-devices']).then(result => {
      return JSON.parse(result.stdout);
    });
  }
  // resolves if the recording started successfully
  // rejects if the recording didn't started after 5 seconds or if some error
  // occurs during the recording session
  startRecording({
    fps = 30,
    cropArea = 'none', // can be 'none' or {x, y, width, height} – TODO: document this
    showCursor = true,
    highlightClicks = false,
    audioSourceId // one of the `id`s from getAudioSources()
  } = {}) {
    return new Promise((resolve, reject) => {
      this.tmpPath = tmp.tmpNameSync({postfix: '.mp4'});

      if (typeof cropArea === 'object') { // TODO validate this
        cropArea = `${cropArea.x}:${cropArea.y}:${cropArea.width}:${cropArea.height}`;
      }

      const recorderOpts = [this.tmpPath, fps, cropArea, showCursor, highlightClicks, audioSourceId];

      this.recorder = execa(path.join(__dirname, 'swift', 'main'), recorderOpts);

      const timeout = setTimeout(() => {
        const err = new Error('unnable to start the recorder after 5 seconds');
        err.code = 'RECORDER_TIMEOUT';

        this.recorder.kill();

        reject(err);
      }, 5000);

      this.recorder.stdout.on('data', data => {
        data = data.toString();

        log(data);

        if (data.replace(/\n|\s/gm, '') === 'R') {
          // `R` is printed by Swift when the recording **actually** starts
          clearTimeout(timeout);
          resolve(this.tmpPath);
        }
      });
      this.recorder.on('error', reject); // TODO handle this;
      this.recorder.on('exit', code => {
        clearTimeout(timeout);
        let err;
        if (code === 0) {
          return; // we're good
        } else if (code === 1) {
          err = new Error('malformed arguments'); // TODO
        } else if (code === 2) {
          err = new Error('invalid coordinates'); // TODO
        } else {
          err = new Error('unknown error'); // TODO
        }
        reject(err);
      });
    });
  }

  stopRecording() {
    return new Promise((resolve, reject) => {
      if (this.recorder === undefined) {
        reject('call `startRecording` first');
      }

      this.recorder.on('exit', code => {
        // at this point the movie file has been fully written to the file system
        if (code === 0) {
          delete this.recorder;

          resolve(this.tmpPath);
          // TODO: this file is deleted when the program exits
          // maybe we should add a note about this on the docs or implement a workaround
          delete this.tmpPath;
        } else {
          reject(code); // TODO
        }
      });

      this.recorder.stdin.write('\n');
    });
  }
}

module.exports = () => new Aperture();
