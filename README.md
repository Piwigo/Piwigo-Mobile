# Piwigo Mobile
Piwigo Mobile is a native iOS Application for Piwigo.

Piwigo is a web photo gallery, built by an active community of users and developers.

##Video 
For video upload using your iOS device, you need the plugin on your Piwigo server titled "VideoJS". After you've installed this plugin, you will need to allow for video file types to be uploaded. You can do this by adding:

        $conf['upload_form_all_types'] = true;
        $conf['file_ext'] =  array('jpg','JPG','jpeg','JPEG','png','PNG','gif','GIF','mpg','zip','avi','mp3','ogg','mov','MOV');

to your local config file using the "LocalFiles Editor" plugin (you just have to activate this).

##License
The MIT License (MIT)

Copyright (c) 2015 Spencer Baker

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
