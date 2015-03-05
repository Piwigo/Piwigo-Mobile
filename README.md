# Piwigo Mobile
Piwigo Mobile is a native iOS Application for Piwigo.

Piwigo is a web photo gallery, built by an active community of users and developers.

##Video 
For video upload using your iOS device, you need the plugin on your Piwigo server titled "VideoJS". After you've installed this plugin, you will need to allow for video file types to be uploaded. You can do this by adding:


        $conf['file_ext'] =  array('jpg','JPG','jpeg','JPEG','png','PNG','gif','GIF','mpg','zip','avi','mp3','ogg','mov','MOV');


to your local config file using the "LocalFiles Editor" plugin (you just have to activate this).
