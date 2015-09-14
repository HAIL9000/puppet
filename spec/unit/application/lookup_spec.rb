require 'spec_helper'
require 'puppet/application/lookup'
require 'puppet/pops/lookup'

describe Puppet::Application::Lookup do

  def assemble_and_compile(fmt, *lookup_args)
    assemble_and_compile_with_block(fmt, "'no_block_present'", *lookup_args)
  end

  def assemble_and_compile_with_block(fmt, block, *lookup_args)
    compile_and_get_notifications <<-END.gsub(/^ {6}/, '')
      $args = [#{lookup_args.join(',')}]
      $block = #{block}
      include abc
      $r = if $abc::result == undef { 'no_value' } else { $abc::result }
      notify { \"#{fmt}\": }
      END
  end

  def compile_and_get_notifications(code)
    Puppet[:code] = code
    compiler.compile().resources.map(&:ref).select { |r| r.start_with?('Notify[') }.map { |r| r[7..-2] }
  end

  # There is a fully configured 'production' environment in fixtures at this location
  let(:environmentpath) { File.join(my_fixture_dir, 'environments') }
  let(:node) { Puppet::Node.new("testnode", :facts => Puppet::Node::Facts.new("facts", {}), :environment => 'production') }
  #let(:compiler) { Puppet::Parser::Compiler.new(node) }

  around(:each) do |example|
    # Initialize settings to get a full compile as close as possible to a real
    # environment load
    Puppet.settings.initialize_global_settings

    # Initialize loaders based on the environmentpath. It does not work to
    # just set the setting environmentpath for some reason - this achieves the same:
    # - first a loader is created, loading directory environments from the fixture (there is
    # one environment, 'sample', which will be loaded since the node references this
    # environment by name).
    # - secondly, the created env loader is set as 'environments' in the puppet context.
    #
    environments = Puppet::Environments::Directories.new(environmentpath, [])
    Puppet.override(:environments => environments) do
      example.run
    end
  end

  context "when running with incorrect command line options" do
    let (:lookup) { Puppet::Application[:lookup] }

    it "errors if no keys are given via the command line" do
      lookup.options[:node] = 'dantooine.local'
      expected_error = "No keys were given to lookup."

      expect{ lookup.run_command }.to raise_error(RuntimeError, expected_error)
    end

    it "errors if no node was given via the --node flag" do
      lookup.command_line.stubs(:args).returns(['atton', 'kreia'])

      expected_error = "No node was given via the '--node' flag for the scope of the lookup."

      expect{ lookup.run_command }.to raise_error(RuntimeError, expected_error)
    end

    it "does not allow deep merge options if '--merge' was not set to deep" do
      lookup.options[:node] = 'dantooine.local'
      lookup.options[:merge_hash_arrays] = true
      lookup.options[:merge] = 'hash'
      lookup.command_line.stubs(:args).returns(['atton', 'kreia'])

      expected_error = "The options --knock_out_prefix, --sort_merged_arrays, --unpack_arrays, and --merge_hash_arrays are only available with '--merge deep'\nRun 'puppet lookup --help' for more details"

      expect{ lookup.run_command }.to raise_error(RuntimeError, expected_error)
    end
  end

  context "when running with correct command line options" do
    let (:lookup) { Puppet::Application[:lookup] }

    it "prints the value found by lookup" do
      lookup.options[:node] = 'dantooine.local'
      lookup.command_line.stubs(:args).returns(['atton', 'kreia'])
      lookup.stubs(:generate_scope).returns('scope')

      Puppet::Pops::Lookup.stubs(:lookup).returns('rand')

      expect{ lookup.run_command }.to output("rand\n").to_stdout
    end

    it "does stuff right" do
      lookup.options[:node] = 'testnode'
      lookup.command_line.stubs(:args).returns(['abc::a'])
      lookup.run_command
    end
  end
end
