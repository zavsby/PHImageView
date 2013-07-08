<h1>PHImageView</h1>
<h3>Objective-C/iOS 5.1+</h3>

<b>ARC Required</b>

This library provides image downloading and caching on iOS.

<b>Adding PHImageView to your project:</b><br/>
1. Add <i>PHImageView</i> folder to the project.<br/>
2. Import <i>PHImageView.h</i> into your <i>.h</i> file.

<h2>Usage</h2>

PHImageView inherits from UIImageView. You can create it using XIB file or from code (with <i>-initWithURL</i> methods).<br/>
To start loading image you should perform one of the <i>-(void)loadImage</i> methods.<br/>

<b>Temperary cache</b> can be cleared by using <i>-(void)clearTemperalyImagesInMemory</i> and <i>-(void)clearTemperalyImageOnDisk</i>. You should use temperaly cache if you want to remove after certain event or exiting from application.<br/>

<b>PHImageCacheParams</b> object specifies some parameters:
<ul>
	<li><i>isTemperaly</i> - makes image temperaly;</li>
	<li><i>shouldSaveToDiskCache</i> - you can save image only in memory cache;</li>
	<li><i>argument</i> - custom object you want to use with imageView</li>
	<li><i>transformSelector</i> and <i>transformTarget</i> - method will be performed after downloading image but before saving it to the cache. Method should have <i>-(UIImage *)method:(UIImage *)image</i> signature and can transform image.</li>
</ul>

<b>PHImageCacheManager</b> has several preferences. You can change maximum disk cache size, maximum memory cache elements and maximum number of threads working at the same time.<br/>

<i>Additional information and example project will be provided soon!</i>