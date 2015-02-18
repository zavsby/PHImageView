# PHImageView
<h3>Objective-C/iOS 7.0+</h3>

This library provides image downloading and caching (two levels) on iOS.

## Usage

PHImageView inherits from UIImageView. You can create it using XIB file or from code (with <i>-initWithURL</i> methods).<br/>
To start loading image you should perform one of the <i>-(void)loadImage</i> methods.<br/>

<b>Temperary cache</b> can be cleared by using <i>-(void)clearTemperalyImagesInMemory</i> and <i>-(void)clearTemperalyImageOnDisk</i>. You should use temperaly cache if you want to remove after certain event or exiting from application.<br/>

<b>PHImageCacheParams</b> object specifies some parameters:
<ul>
	<li><i>isTemperaly</i> - makes image temperaly;</li>
	<li><i>shouldSaveToDiskCache</i> - you can save image only in memory cache;</li>
	<li><i>argument</i> - custom object you want to use with imageView</li>
</ul>

<b>PHImageCacheManager</b> has several preferences. You can change maximum disk cache size, maximum memory cache elements and maximum number of threads working at the same time and other.<br/>

<i>Additional information and example project will be provided soon!</i>

## Requirements

## Installation

PHImageView is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

    pod "PHImageView"

## Author

Sergey P., zavsby@gmail.com

## License

PHImageView is available under the MIT license. See the LICENSE file for more info.
