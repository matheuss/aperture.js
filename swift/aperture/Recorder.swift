import AVFoundation;

public class Recorder: NSObject, AVCaptureFileOutputRecordingDelegate {
  var destination: NSURL?;
  var session: AVCaptureSession?;
  var input: AVCaptureScreenInput?
  var audioInput: AVCaptureDeviceInput?
  var output: AVCaptureMovieFileOutput?;

  public init(destinationPath: String, fps: String, coordinates: [String], showCursor: Bool, highlightClicks: Bool, audioDeviceId: String) {
    super.init();
    self.session = AVCaptureSession();

    let displayId: CGDirectDisplayID = CGMainDisplayID();

    self.input = AVCaptureScreenInput(displayID: displayId);

    if (audioDeviceId != "none") {
      let audioDevice: AVCaptureDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeAudio)

      do {
        try self.audioInput = AVCaptureDeviceInput(device: audioDevice)
      } catch{}

      if ((self.session?.canAddInput(self.audioInput)) != nil) {
        self.session?.addInput(self.audioInput);
      } else {
        print("Can't add audio input");
      }
    }

    if ((self.session?.canAddInput(input)) != nil) {
      self.session?.addInput(input);
    } else {
      print("Can't add input"); // TODO
    }

    self.output = AVCaptureMovieFileOutput();

    // write data to file every 2 seconds
    // writing every 1 second causes intermittent errors
    self.output?.movieFragmentInterval = CMTimeMakeWithSeconds(2, 1);

    if ((self.session?.canAddOutput(self.output)) != nil) {
      self.session?.addOutput(self.output);
    } else {
      print("can't add output"); // TODO
    }

    let conn = self.output?.connectionWithMediaType(AVMediaTypeVideo);
    let cmTime = CMTimeMake(1, Int32(fps)!);
    conn?.videoMinFrameDuration = cmTime; // TODO check if can set
    conn?.videoMaxFrameDuration = cmTime; // TODO ^^^^^^^^^^^^^^^^

    self.destination = NSURL.fileURLWithPath(destinationPath);

    if (coordinates.count != 0) {
      let points = coordinates.map { CGFloat((Int($0))!) };
      let rect = CGRectMake(points[0], points[1], points[2], points[3]); // x, y, width, height
      self.input?.cropRect = rect;
    }

    self.input?.capturesCursor = showCursor;
    self.input?.capturesMouseClicks = highlightClicks;
  }

  public func start() {
      self.session?.startRunning();
      self.output?.startRecordingToOutputFileURL(self.destination, recordingDelegate: self);
    }

  public func stop() {
      self.output?.stopRecording();
      self.session?.stopRunning();
  }

  public func captureOutput(captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAtURL fileURL: NSURL!, fromConnections connections: [AnyObject]!) {
    print("R"); // at this point the recording really started
  }

  public func captureOutput(captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAtURL outputFileURL: NSURL!, fromConnections connections: [AnyObject]!, error: NSError!) {
    print(error);
  }
}
