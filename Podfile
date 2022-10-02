# Uncomment the next line to define a global platform for your project
platform :ios, '12.0'

target 'piwigo' do
  # Uncomment the next line if you're using Swift or would like to use dynamic frameworks
  # use_frameworks!

  pre_install do |installer|
      puts 'pre_install begin....'
      dir_af = File.join(installer.sandbox.pod_dir('AFNetworking'), 'UIKit+AFNetworking')
      Dir.foreach(dir_af) {|x|
        real_path = File.join(dir_af, x)
        if (!File.directory?(real_path) && File.exists?(real_path))
          if((x.start_with?('UIWebView') || x == 'UIKit+AFNetworking.h'))
            File.delete(real_path)
            puts 'delete:'+ x
          end
        end
      }
      puts 'end pre_install.'
  end

  # Pods for piwigo
  pod 'AFNetworking'
  pod 'MBProgressHUD'
  pod 'MGSwipeTableCell'
  pod 'IQKeyboardManagerSwift'

  target 'piwigoAppStore' do
    inherit! :search_paths
    # Pods for testing
  end

end
