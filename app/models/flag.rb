class Flag < ActiveRecord::Base
	belongs_to :flaggable, polymorphic: true
	has_one :usersession, :foreign_key => :session_id, :primary_key => :session_id
	attr_accessible :flag_value, :is_primary, :flaggable_type, :flaggable_id, :session_id, :flag_type, :latitude, :longitude
	validates :flag_value, presence: true
	validates :flaggable_type, presence: true
	validates :flaggable_id, presence: true
	validates :flag_type, presence: true

	def self.flags_for_sheet_for_session(sheet_id, session_id, type = "geometry")
		# just need the count
		if type != "toponym"
			Flag.select('DISTINCT flags.flaggable_id, flags.latitude, flags.longitude, flags.flag_value, polygons.geometry, polygons.sheet_id, polygons.dn').joins("INNER JOIN polygons ON polygons.id = flags.flaggable_id INNER JOIN sheets ON sheets.id = polygons.sheet_id").where('sheets.id = ? AND flags.session_id = ? AND flags.flag_type = ?', sheet_id, session_id, type)
		else
			Flag.select('DISTINCT flags.flaggable_id, flags.latitude, flags.longitude, flags.flag_value').joins("INNER JOIN sheets ON sheets.id = flags.flaggable_id").where('sheets.id = ? AND flags.session_id = ? AND flags.flag_type = ?', sheet_id, session_id, type)
		end
	end

	def self.flags_for_sheet_for_user(sheet_id, user_id, type = "geometry")
		# just need the count
		if type != "toponym"
			Flag.select('DISTINCT flags.flaggable_id, flags.latitude, flags.longitude, flags.flag_value, polygons.geometry, polygons.sheet_id, polygons.dn').joins("INNER JOIN polygons ON polygons.id = flags.flaggable_id INNER JOIN sheets ON sheets.id = polygons.sheet_id").joins(:usersession).where('sheets.id = ? AND usersessions.user_id = ? AND flags.flag_type = ?', sheet_id, user_id, type)
		else
			Flag.select('DISTINCT flags.flaggable_id, flags.latitude, flags.longitude, flags.flag_value').joins("INNER JOIN sheets ON sheets.id = flags.flaggable_id").joins(:usersession).where('sheets.id = ? AND usersessions.user_id = ? AND flags.flag_type = ?', sheet_id, user_id, type)
		end
	end

	def self.grouped_flags_for_session(session_id, layer_id, type = "geometry")
		# just need the count per sheet
		if type != "toponym"
			Flag.select('COUNT(DISTINCT flags.flaggable_id) as total, sheets.id, sheets.bbox').joins("INNER JOIN polygons ON polygons.id = flags.flaggable_id INNER JOIN sheets ON sheets.id = polygons.sheet_id").where('flags.session_id = ? AND flags.flag_type = ? AND sheets.layer_id = ?', session_id, type, layer_id).group("sheets.id")
		else
			Flag.select('COUNT(flags.id) as total, sheets.id, sheets.bbox').joins("INNER JOIN sheets ON sheets.id = flags.flaggable_id").where('flags.session_id = ? AND flags.flag_type = ? AND sheets.layer_id = ?', session_id, type, layer_id).group("sheets.id")
		end
	end

	def self.grouped_flags_for_user(user_id, layer_id, type = "geometry")
		# just need the count per sheet
		if type != "toponym"
			Flag.select('COUNT(DISTINCT flags.flaggable_id) as total, sheets.id, sheets.bbox').joins("INNER JOIN polygons ON polygons.id = flags.flaggable_id INNER JOIN sheets ON sheets.id = polygons.sheet_id").joins(:usersession).where('usersessions.user_id = ? AND flags.flag_type = ? AND sheets.layer_id = ?', user_id, type, layer_id).group("sheets.id")
		else
			Flag.select('COUNT(flags.id) as total, sheets.id, sheets.bbox').joins("INNER JOIN sheets ON sheets.id = flags.flaggable_id").joins(:usersession).where('usersessions.user_id = ? AND flags.flag_type = ? AND sheets.layer_id = ?', user_id, type, layer_id).group("sheets.id")
		end
	end

	def self.flags_for_session(session_id, type = "geometry")
		if type != "toponym"
			Flag.select("DISTINCT flaggable_id").where("session_id = ? AND flag_type = ?", session_id, type).count
		else
			Flag.select("DISTINCT flags.id").where("session_id = ? AND flag_type = ?", session_id, type).count
		end
	end

	def self.flags_for_user(user_id, type = "geometry")
		if type != "toponym"
			Flag.select("DISTINCT flaggable_id").joins(:usersession).where('usersessions.user_id = ? AND flags.flag_type = ?', user_id, type).count
		else
			Flag.select("DISTINCT flags.id").joins(:usersession).where('usersessions.user_id = ? AND flags.flag_type = ?', user_id, type).count
		end
	end

	def self.progress_for_session(session_id, type = "geometry")
		if type != "toponym"
			Flag.select("DISTINCT polygons.id, polygons.centroid_lat, polygons.centroid_lon, polygons.geometry, flags.*").joins(:polygon).where("flags.session_id = ? AND flags.flag_type = ?", session_id, type)
		else
			Flag.select("flags.*").joins("INNER JOIN sheets ON sheets.id = flags.flaggable_id").where("flags.session_id = ? AND flags.flag_type = ?", session_id, type)
		end
	end

	def self.progress_for_user(user_id, type = "geometry")
		if type != "toponym"
			Flag.select("DISTINCT polygons.id, polygons.centroid_lat, polygons.centroid_lon, polygons.geometry, flags.*").joins(:polygon).joins(:usersession).where('usersessions.user_id = ? AND flags.flag_type = ?', user_id, type)
		else
			Flag.select("flags.*").joins("INNER JOIN sheets ON sheets.id = flags.flaggable_id").joins(:usersession).where('usersessions.user_id = ? AND flags.flag_type = ?', user_id, type)
		end
	end

	def self.flags_for_sheet_for_task_and_threshold(sheet_id, type = "polygonfix", threshold = 3)
		sql = Flag.send(:sanitize_sql_array,["SELECT f.flaggable_id, f.id, f.flag_value FROM flags f INNER JOIN ( SELECT _f.flaggable_id pid, COUNT(*) qty FROM flags _f INNER JOIN polygons _p ON _p.id = _f.flaggable_id AND _f.flag_type =  ? WHERE _p.sheet_id = ? GROUP BY pid HAVING COUNT(*) >= ? ) j1 ON j1.pid = f.flaggable_id WHERE f.flag_type =  ? ORDER BY f.flaggable_id", type, sheet_id, threshold, type])
		Flag.connection.execute(sql)
	end

	def self.flags_for_sheet_for_task(sheet_id, type = "address")
		Flag.joins("INNER JOIN polygons ON polygons.id = flags.flaggable_id").where("sheet_id = ? AND flag_type = ? AND latitude IS NOT NULL AND longitude IS NOT NULL", sheet_id, type)
	end

  def self.all_as_features(type = "geometry")
    features = []

    f = Flag.where(:flag_type => type)
    f.each do |feature|
      features.push(feature.as_feature)
    end

    { :type => "FeatureCollection", :features => features }
  end

	def as_feature
		# commented out the query for user to improve performance
		# user = Usersession.where(:session_id => self[:session_id]).first
		r = {}
		if self[:latitude] == nil || self[:longitude] == nil
			p = self.flaggable
			self[:latitude] = p[:centroid_lat]
			self[:longitude] = p[:centroid_lon]
		end
		r[:type] = "Feature"
		r[:properties] = {}
		r[:properties][:id] = self[:id]
		# if user != nil
		# 	r[:properties][:user_id] = user[:user_id]
		# else
			r[:properties][:session_id] = self[:session_id]
		# end
		if self[:flag_type] == 'polygonfix' && self[:flag_value] != "NOFIX"
			r[:geometry] = { :type => "Polygon", :coordinates => JSON.parse(self[:flag_value]) }
		else
			r[:properties][:flag_value] = self[:flag_value]
			r[:geometry] = { :type => "Point", :coordinates => [self[:longitude].to_f, self[:latitude].to_f] }
		end
		r
	end

end
