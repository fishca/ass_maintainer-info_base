require 'test_helper'

module AssMaintainer::InfoBaseTest
  describe AssMaintainer::InfoBase::FileIb do
    attr_reader :file_ib
    before do
      @file_ib = Class.new(AssMaintainer::InfoBase) do
        def initialize
          super '', 'File="/tmp/facke_ib";'
        end
      end.new
    end

    do_nothing_methods = [:lock, :unlock, :unlock!, :lock_schjobs, :unlock_schjobs]

    do_nothing_methods.each do |m|
      it "#{m} do nothing" do
        assert_nil file_ib.send m
      end
    end

    it '#sessions always returns empty array' do
      file_ib.sessions.must_equal []
    end

    it '#locked always false' do
      file_ib.locked?.must_equal false
    end

    it '#exists?' do
      File.expects(:file?)
        .with(File.join(file_ib.connection_string.path,'1Cv8.1CD'))
        .returns(:may_be_exists)
      file_ib.exists?.must_equal :may_be_exists
    end

    it '#maker' do
      file_ib.send(:maker)
        .must_be_instance_of AssMaintainer::InfoBase::DefaultMaker
      file_ib.options[:maker] = :fake_maiker
      file_ib.send(:maker).must_equal :fake_maiker
    end

    it '#destroyer' do
      file_ib.send(:destroyer)
        .must_be_instance_of AssMaintainer::InfoBase::FileIb::FileBaseDestroyer
      file_ib.options[:destroyer] = :fake_destroyer
      file_ib.send(:destroyer).must_equal :fake_destroyer
    end
  end

  describe AssMaintainer::InfoBase::FileIb::FileBaseDestroyer do
    it '#entry_point' do
      cs = mock
      cs.expects(:path).returns('fake_path_to_infobase')
      infobase = mock
      infobase.expects(:connection_string).returns(cs)
      FileUtils.expects(:rm_r).with('fake_path_to_infobase')
      destroyer = self.class.desc.new
      destroyer.execute(infobase)
    end
  end
end
