require 'spec_helper'

describe Lumberjack::Device::DateRollingLogFile do

  before :all do
    create_tmp_dir
  end
  
  after :all do
    delete_tmp_dir
  end
  
  let(:one_day){ 60 * 60 * 24 }
  
  it "should roll the file daily" do
    today = Date.today
    now = Time.now
    log_file = File.join(tmp_dir, "a#{rand(1000000000)}.log")
    device = Lumberjack::Device::DateRollingLogFile.new(log_file, :roll => :daily, :template => ":message")
    logger = Lumberjack::Logger.new(device, :buffer_size => 2)
    logger.error("test day one")
    logger.flush
    Time.stub!(:now).and_return(now + one_day)
    Date.stub!(:today).and_return(today + 1)
    logger.error("test day two")
    logger.close
    
    File.read("#{log_file}.#{today.strftime('%Y-%m-%d')}").should == "test day one#{Lumberjack::LINE_SEPARATOR}"
    File.read(log_file).should == "test day two#{Lumberjack::LINE_SEPARATOR}"
  end

  it "should roll the file daily - even when running incrementally (not a daemon)" do
    today = Date.today
    now = Time.now
    log_file = File.join(tmp_dir, "a1#{rand(1000000000)}.log")
    device = Lumberjack::Device::DateRollingLogFile.new(log_file, :roll => :daily, :template => ":message")
    logger = Lumberjack::Logger.new(device, :buffer_size => 2)
    logger.error("test day one")
    logger.flush
    logger.close
    # time change and then restart - diffent than the case above where starting and then date change
    Time.stub!(:now).and_return(now + one_day)
    Date.stub!(:today).and_return(today + 1)
    device = Lumberjack::Device::DateRollingLogFile.new(log_file, :roll => :daily, :template => ":message")
    logger = Lumberjack::Logger.new(device, :buffer_size => 2)
    logger.error("test day two")
    logger.close
    File.read("#{log_file}.#{today.strftime('%Y-%m-%d')}").should == "test day one#{Lumberjack::LINE_SEPARATOR}"
    File.read(log_file).should == "test day two#{Lumberjack::LINE_SEPARATOR}"
  end

  it "should roll the file daily and append correct date - even when a long time has passed" do
    today = Date.today
    now = Time.now
    a_week_ago = today - 7
    a_week_ago_time = now - 7*one_day
    Time.stub!(:now).and_return(a_week_ago_time)
    Date.stub!(:today).and_return(a_week_ago)
    log_file = File.join(tmp_dir, "a2#{rand(1000000000)}.log")
    device = Lumberjack::Device::DateRollingLogFile.new(log_file, :roll => :daily, :template => ":message")
    logger = Lumberjack::Logger.new(device, :buffer_size => 2)
    logger.error("test day one")
    logger.flush
    logger.close
    File.utime(a_week_ago_time, a_week_ago_time, log_file) #because the stubbed time doesn't fool the system....
    # time change and then restart - but let a week pass
    Time.stub!(:now).and_return(now)
    Date.stub!(:today).and_return(today)
    device = Lumberjack::Device::DateRollingLogFile.new(log_file, :roll => :daily, :template => ":message")
    logger = Lumberjack::Logger.new(device, :buffer_size => 2)
    logger.error("test day two")
    logger.close
    File.read("#{log_file}.#{a_week_ago.strftime('%Y-%m-%d')}").should == "test day one#{Lumberjack::LINE_SEPARATOR}"
    File.read(log_file).should == "test day two#{Lumberjack::LINE_SEPARATOR}"
  end

  # change of behavior from previous (but broken) implementation
  it "should roll the file weekly" do
    today = Date.today
    now = Time.now
    log_file = File.join(tmp_dir, "b#{rand(1000000000)}.log")
    device = Lumberjack::Device::DateRollingLogFile.new(log_file, :roll => :weekly, :template => ":message")
    logger = Lumberjack::Logger.new(device, :buffer_size => 2)
    logger.error("test week one")
    logger.flush
    Time.stub!(:now).and_return(now + (7 * one_day))
    Date.stub!(:today).and_return(today + 7)
    logger.error("test week two")
    logger.close
    
    eow = (today + 7 - today.cwday)
    File.read("#{log_file}.#{eow.strftime('week-of-%Y-%m-%d')}").should == "test week one#{Lumberjack::LINE_SEPARATOR}"
    File.read(log_file).should == "test week two#{Lumberjack::LINE_SEPARATOR}"
  end

  # change of behavior from previous (but broken) implementation
  it "should append end of week timestamp to weekly files" do
    # test beginning, middle, end of week - all should produce same results
    last_monday =   (Date.parse('Monday')   - 7).to_time
    last_thursday = (Date.parse('Thursday') - 7).to_time
    last_sunday = (Date.parse('Sunday') - 0).to_time # Date Parse considers Sunday part of this week, whereas cwday has it as last
    log_file = File.join(tmp_dir, "b1#{rand(1000000000)}.log")

    [last_monday, last_thursday, last_sunday].each do |dow|
      File.new(log_file,'a').close
      File.utime(dow, dow, log_file)
      device = Lumberjack::Device::DateRollingLogFile.new(log_file, :roll => :weekly, :template => ":message")
      logger = Lumberjack::Logger.new(device, :buffer_size => 2)
      logger.error("test rolls old, and logs to new file")
      logger.close
      File.exists?("#{log_file}.#{last_sunday.strftime('week-of-%Y-%m-%d')}").should be_true
      File.unlink("#{log_file}.#{last_sunday.strftime('week-of-%Y-%m-%d')}").should be_true
    end
  end

  it "should roll the file monthly" do
    today = Date.today
    now = Time.now
    log_file = File.join(tmp_dir, "c#{rand(1000000000)}.log")
    device = Lumberjack::Device::DateRollingLogFile.new(log_file, :roll => :monthly, :template => ":message")
    logger = Lumberjack::Logger.new(device, :buffer_size => 2)
    logger.error("test month one")
    logger.flush
    Time.stub!(:now).and_return(now + (31 * one_day))
    Date.stub!(:today).and_return(today + 31)
    logger.error("test month two")
    logger.close
    
    File.read("#{log_file}.#{today.strftime('%Y-%m')}").should == "test month one#{Lumberjack::LINE_SEPARATOR}"
    File.read(log_file).should == "test month two#{Lumberjack::LINE_SEPARATOR}"
  end

end
