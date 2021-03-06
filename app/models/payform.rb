class Payform < ActiveRecord::Base
  has_and_belongs_to_many :payform_items
  belongs_to :department
  belongs_to :user

  validates_presence_of :week, :year, :department_id, :user_id

  named_scope :unsubmitted, lambda { |dept_id| {
    :conditions => ["department_id = ? AND submitted IS ?", dept_id, nil]
  }}
  named_scope :unapproved, lambda { |dept_id| {
    :conditions => ["department_id = ? AND submitted IS NOT ? AND approved IS ?", dept_id, nil, nil]
  }}
  named_scope :unprinted, lambda { |dept_id| {
    :conditions => ["department_id = ? AND approved IS NOT ? AND printed IS ?", dept_id, nil, nil]
  }}
  named_scope :in_department, lambda { |dept_id| { :conditions => ["department_id = ?", dept_id] }}

  def get_status_text
    self.printed ? 'printed' : self.approved ? 'approved' : self.submitted ? 'submitted' : 'unsubmitted'
  end

  def get_dates
    Payform.get_days(self.year, self.week)
  end

  def get_date
    Payform.get_day(self.year, self.week)
  end

  def self.get_days (year, week)
    dates = []
    7.times {|n| d = get_day(year, week)+(n-6)
      dates << d unless d > Date.today}
    dates
  end

  def self.get_day (year, week)
    Date.commercial(year, week, 6)
  end

  def valid_user?(user)
    self.user_id == user.id ? true : false
  end

  def authorized?(user, controller_name)
    if controller_name == 'payform'
      self.user_id == user.id and user.authorized?(self.department.payform_configuration.payform_permission.name) ? true : false
    else
      user.authorized?(self.department.payform_configuration.payform_admin_permission.name) ? true : false
    end
  end

  #gets the payform with the given commercial week#, year, user id, and department id
  def self.get_payform(week, year, user, department)
    Payform.first(:conditions => ["user_id = ? and week = ? and year = ? and department_id = ?", user.id, week, year, department.id])
  end

  #finds or creates a payform with the given week, year, user, and department
  def self.find_or_create(week, year, user, department)
    payform = Payform.get_payform(week, year, user, department)
    unless payform
      payform = Payform.create(:week => week, :year => year, :user_id => user.id,:department_id => department.id)
    end
    payform
  end

  def unsubmit
    if self.submitted and !self.printed
      self.submitted = self.approved = self.approved_by = nil
      unless self.save
        return false
      end
    elsif self.printed
      return false
    end
    return true
  end

  def unapprove
    if self.approved and !self.printed
      self.approved = nil
      unless self.save
        return false
      end
    elsif self.printed
      return false
    end
    return true
  end

  def total_hours
    @total_hours ||= round_up_to_nearest_quarter_hour self.payform_items.active.to_a.sum(&:hours)
  end

  def category_hours(cat_id)
    self.payform_items.to_a.sum { |p| (p.category_id == cat_id and p.active?) ? p.hours : 0 }
  end

  # admin returns all jobs, otherwise only active jobs returned
  # OPTIMIZE: should this be a helper method since you are getting the "admin" value from the is_admin? helper method
  def misc_jobs(admin=false)
    m_jobs = Array.new(self.payform_items)
    for category in Category.active(department.id)
      m_jobs.delete_if { |p| p.category_id == category.id or (department.payform_configuration.show_disabled_cats and p.category)}
    end
    admin ? m_jobs : (m_jobs.compact.collect do |p| p if p.active? end).compact
  end

  def has_active_shifts?
    current_report = ShiftReport.find_current_report(self.user)
    if current_report && current_report.start < (self.get_date + 1)
      return true
    else
      return false
    end
  end

  protected

  # METHODS TO ROUND TOTAL HOURS TO NEAREST QUARTER HOUR
  def round_up_to_nearest_quarter_hour(hours)
    round_up(hours*4)/4
  end

  def round_up(num, nearest=1)
    num % nearest == 0 ? num : num + nearest - (num % nearest)
  end

  def validate
    if (approved or printed) and !submitted
      errors.add("Cannot approve or print unsubmitted payform, so the submitted field")
    end
    if printed and !approved
      errors.add("Cannot print unapproved payform, so the approved field")
    end
    unless user.authorized?(department.payform_configuration.payform_permission.name)
      errors.add("Payform owner is not authorized for payform department")
    end
  end







end
