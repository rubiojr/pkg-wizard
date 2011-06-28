require 'pkg-wizard'
require 'pkg-wizard/rpm'
require 'test/unit'

include PKGWizard

class SpecFileTest < Test::Unit::TestCase


  def test_sources
    assert SpecFile.parse('').sources.empty?
    assert SpecFile.parse("""
       Source: foobar
       Source1: stuff
       Source0: bar
    """).sources.size == 3
  end

  def test_name
    assert SpecFile.parse('').name.nil?
    assert SpecFile.parse('Name: package-foo').name == 'package-foo'
    assert SpecFile.parse('name: package-foo').name == 'package-foo'
  end
  
  def test_version
    assert SpecFile.parse('').version.nil?
    assert SpecFile.parse('Version: 1.1').version == '1.1'
    assert SpecFile.parse('version: 1.1').version == '1.1'
  end

  def test_release
    assert SpecFile.parse('').release.nil?
    assert SpecFile.parse('Release: 1').release == '1'
    assert SpecFile.parse('release: 1').release == '1'
  end

  def test_files
    assert SpecFile.parse('').files.empty?
    assert SpecFile.parse("""
       Source: foobar
       Source1: stuff
       Source0: bar
       Name: foo
       Release: 1
       Version: 1.1
       %pre
       foo
       %install
       %post
       foo
       %files
       /foo/bar
       %config /etc/foo
       %defattr(-,root,root)
       
       %changelog
    """).files.size == 3
    assert SpecFile.parse("""
       Source: foobar
       Source1: stuff
       Source0: bar
       Name: foo
       Release: 1
       Version: 1.1
       %pre
       foo
       %install
       %post
       foo
       %files
       /foo/bar
       %config /etc/foo
       %defattr(-,root,root)
       
       %changelog
    """).files.first == '/foo/bar'
  end

end
