D "Whitestone.stop" do
  D "Benign first test" do
    T { 1 + 1 == 2 }
  end
  D "Here we go" do
    if defined? Whitestone
      Whitestone.stop
    elsif defined? Dfect
      Dfect.stop
    end
    raise "Must not get here"
  end
  D "Must not get here" do
    raise "Must not get here"
  end
end
