# encoding: utf-8
require_relative "../spec_helper"
require "stud/temporary"
require 'logstash/inputs/lumberjack'
require "logstash/codecs/plain"
require "logstash/codecs/multiline"
require "logstash/event"
require "lumberjack/client"

Thread.abort_on_exception = true
describe LogStash::Inputs::Lumberjack do
  let(:connection) { double("connection") }
  let(:certificate) { LogStashTest.certificate }
  let(:port) { LogStashTest.random_port }
  let(:queue)  { Queue.new }
  let(:config)   { { "port" => 0, "ssl_certificate" => certificate.ssl_cert, "ssl_key" => certificate.ssl_key, "type" => "example", "tags" => "lumberjack" } }

  subject(:lumberjack) { LogStash::Inputs::Lumberjack.new(config) }

  context "#register" do
    it "raise no exception" do
      plugin = LogStash::Inputs::Lumberjack.new(config)
      expect { plugin.register }.not_to raise_error
    end

    context "with ssl enabled" do
      context "without certificate configuration" do
        let(:config) {{ "port" => 0, "ssl_key" => certificate.ssl_key, "type" => "example", "tags" => "lumberjack" }}

        it "should fail to register the plugin with ConfigurationError" do
          plugin = LogStash::Inputs::Lumberjack.new(config)
          expect {plugin.register}.to raise_error(LogStash::ConfigurationError)
        end
      end

      context "without key configuration" do
        let(:config)   { { "port" => 0, "ssl_certificate" => certificate.ssl_cert, "type" => "example", "tags" => "lumberjack" } }
        it "should fail to register the plugin with ConfigurationError" do
          plugin = LogStash::Inputs::Lumberjack.new(config)
          expect {plugin.register}.to raise_error(LogStash::ConfigurationError)
        end
      end
    end

    context "with ssl disabled" do
      context "and certificate configuration" do
        let(:config)   { { "port" => 0, "ssl" => false, "ssl_certificate" => certificate.ssl_cert, "type" => "example", "tags" => "lumberjack" } }

        it "should not fail" do
          plugin = LogStash::Inputs::Lumberjack.new(config)
          expect {plugin.register}.not_to raise_error
        end
      end

      context "and certificate key configuration" do
        let(:config) {{ "port" => 0, "ssl" => false, "ssl_key" => certificate.ssl_key, "type" => "example", "tags" => "lumberjack" }}

        it "should not fail" do
          plugin = LogStash::Inputs::Lumberjack.new(config)
          expect {plugin.register}.not_to raise_error
        end
      end

      context "and no certificate or key configured" do
        let(:config) {{ "ssl" => false, "port" => 0, "type" => "example", "tags" => "lumberjack" }}
        it "should work just fine" do
          plugin = LogStash::Inputs::Lumberjack.new(config)
          expect {plugin.register}.not_to raise_error
        end
      end
    end
  end

  describe "#processing of events" do
    let(:lines) { {"line" => "one\ntwo\n  two.2\nthree\n", "tags" => ["syslog"]} }

    before do
      allow(connection).to receive(:run).and_yield(lines)
      lumberjack.register
      expect_any_instance_of(Lumberjack::Server).to receive(:accept).and_return(connection)
    end

    context "#codecs" do
      let(:config) do
        { "port" => port, "ssl_certificate" => certificate.ssl_cert, "ssl_key" => certificate.ssl_key,
          "type" => "example", "codec" => codec }
      end

      let(:codec) { LogStash::Codecs::Multiline.new("pattern" => '\n', "what" => "previous") }
      it "clone the codec per connection" do
        expect(lumberjack.codec).to receive(:clone).once
        expect(lumberjack).to receive(:invoke) { break }
        lumberjack.run(queue)
      end
    end
  end

  context "when interrupting the plugin" do
    it_behaves_like "an interruptible input plugin"
  end
end
