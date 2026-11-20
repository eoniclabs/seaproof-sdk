Pod::Spec.new do |s|
  s.name = 'seaproof'
  s.version = '0.1.0-beta.1'
  s.summary = 'Seaproof feedback composer for Flutter on iOS.'
  s.homepage = 'https://seaproof.io'
  s.license = { :type => 'MIT', :file => '../LICENSE' }
  s.author = { 'Seaproof' => 'release@seaproof.io' }
  s.source = { :path => '.' }
  s.source_files = 'seaproof/Sources/seaproof/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  s.swift_version = '5.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end
