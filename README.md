# Parrot Anafi Object Detection Demo
This repository demonstrates how to train, quantize, and deploy a few-shot object detection model 
trained on only 5 rubber-ducky images. We deploy the model on iOS for performing inference on live video captured from the Parrot Anafi drone.

It is important to note that this is a proof-of-concept and not intended for production. 

## Requirements

* Parrot Anafi Drone
* Xcode 11.7+
* iOS 12.2+

## App Setup

Open up Terminal, cd into your top-level project directory, and run the following commands

```
pod repo update
pod install
```

Once the pods have been installed, you can open the .xcworkspace file and start coding.

## Object Detection

This app ships with both the trained rubber-ducky detector model, as well as a model trained on the [COCO dataset](https://cocodataset.org/#home). 
By default, the app runs the rubber-ducky model. If you would like to try out the COCO model, you must alter the following in `ModelDataHandler.swift`

```swift
// Replace this 
enum MobileNetSSD {
  static let modelInfo: FileInfo = (name: "ducky", extension: "tflite")
  static let labelsInfo: FileInfo = (name: "ducky_labelmap", extension: "txt")
}
// With this 
enum MobileNetSSD {
  static let modelInfo: FileInfo = (name: "coco", extension: "tflite")
  static let labelsInfo: FileInfo = (name: "coco_labelmap", extension: "txt")
}
```

## Custom Dataset

If you would like to train an object detector, you can follow our example colab notebook [few_shot_object_detection_tflite.ipynb](few_shot_object_detection_tflite.ipynb).

## Acknowledgements

This repository was heavily influenced by the following:
* github.com/riis/parrot
* github.com/tensorflow/models/blob/master/research/object_detection/colab_tutorials/eager_few_shot_od_training_tf2_colab.ipynb, 
* github.com/tensorflow/examples/tree/master/lite/examples/object_detection/ios

## Contributors

Ian Timmis, itimmis@riis.com
