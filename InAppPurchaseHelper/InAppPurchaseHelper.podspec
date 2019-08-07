Pod::Spec.new do |s|
  s.name             = 'InAppPurchaseHelper'
  s.version          = '0.1.0'
  s.summary          = 'Helper class for InAppPurchase.'
 
  s.description      = <<-DESC
Helper class for InAppPurchase!
                       DESC
 
  s.homepage         = 'https://github.com/pradeep7may/InAppPurchaseHelper'
  s.license          = { :type => 'MIT', :text => <<-LICENSE
                   Copyright 2019 iOSBucket
                   Permission is granted to...
                 LICENSE
               }
  s.author           = { 'Pradeep Yadav' => 'pradeep005yadav@rediffmail.com' }
  s.source           = { :git => 'https://github.com/pradeep7may/InAppPurchaseHelper.git', :tag => s.version.to_s }
 
  s.ios.deployment_target = '9.0'
  s.swift_versions = '4.0'
  s.source_files = 'InAppPurchaseHelper/InAppPurchaseHelper/*.{swift}'
 
end