#
# Be sure to run `pod lib lint Euromsg.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'Euromsg'
  s.version          = '2.2.4'
  s.summary          = 'Euromsg SDK'
  s.description      = 'Euromsg SDK'
  s.homepage         = 'https://github.com/relateddigital/euromessage-ios'
  s.license          = 'Related Digital'
  s.author           = { 'Muhammed ARAFA' => 'Muhammed ARAFA' }
  s.source           = { :git => 'https://github.com/relateddigital/euromessage-ios.git', :tag => s.version.to_s }
  s.ios.deployment_target = '10.0'
  s.swift_version = '5.0'
  s.source_files = 'Sources/Euromsg/Classes/**/*'
  s.pod_target_xcconfig = { 'PRODUCT_BUNDLE_IDENTIFIER': 'com.euromsg.EuroFramework' }
end
