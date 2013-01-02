class Sender
  attr_accessor :name, :dates
  
  def initialize(name)
    self.name = name
    self.dates = []
  end
  
  def <<(time)
    self.dates << time.to_date
  end
  
  def sends_by_week
    d = self.dates.group_by{ |d| d.cweek }
    puts d
    d
  end
  
  def count
    self.dates.count
  end
  
  def uniq
    self.dates.uniq.count
  end
  
  # .strftime("%Y-%-m-%-d")
  
end