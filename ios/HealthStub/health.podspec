Pod::Spec.new do |s|
  s.name             = 'health'
  s.version          = '13.3.1'
  s.summary          = 'Stub for health plugin — HealthKit disabled on iOS.'
  s.description      = 'This app uses CoreMotion for step counting on iOS. ' \
                        'The health package is only used for Android Health Connect. ' \
                        'This stub prevents HealthKit from being linked into the iOS binary.'
  s.homepage         = 'https://pub.dev/packages/health'
  s.license          = { :type => 'BSD' }
  s.author           = { 'Stub' => 'stub@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.platform         = :ios, '14.0'
  s.swift_version    = '5.0'
  s.dependency 'Flutter'
end
