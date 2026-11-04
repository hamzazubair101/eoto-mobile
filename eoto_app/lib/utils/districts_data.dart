class DistrictsData {
  /// Pakistan's 7 Administrative Units / Provinces with official districts (~171 districts total)
  static const Map<String, List<String>> provinceDistricts = {
    'Punjab': [
      'Attock', 'Bahawalnagar', 'Bahawalpur', 'Bhakkar', 'Chakwal', 'Chiniot', 
      'Dera Ghazi Khan', 'Faisalabad', 'Gujranwala', 'Gujrat', 'Hafizabad', 
      'Jhang', 'Jhelum', 'Kasur', 'Khanewal', 'Khushab', 'Kot Addu', 'Lahore', 
      'Layyah', 'Lodhran', 'Mandi Bahauddin', 'Mianwali', 'Multan', 'Murree', 
      'Muzaffargarh', 'Nankana Sahib', 'Narowal', 'Okara', 'Pakpattan', 
      'Rahim Yar Khan', 'Rajanpur', 'Rawalpindi', 'Sahiwal', 'Sargodha', 
      'Sheikhupura', 'Sialkot', 'Talagang', 'Taunsa', 'Toba Tek Singh', 
      'Vehari', 'Wazirabad'
    ],
    'Sindh': [
      'Badin', 'Dadu', 'Ghotki', 'Hyderabad', 'Jacobabad', 'Jamshoro', 
      'Karachi Central', 'Karachi East', 'Karachi South', 'Karachi West', 
      'Kashmore', 'Keamari', 'Khairpur', 'Korangi', 'Larkana', 
      'Malir', 'Matiari', 'Mirpur Khas', 'Naushahro Feroze', 'Qambar Shahdadkot', 
      'Sanghar', 'Shaheed Benazirabad (Nawabshah)', 'Shikarpur', 'Sujawal', 
      'Sukkur', 'Tando Allahyar', 'Tando Muhammad Khan', 'Tharparkar', 
      'Thatta', 'Umerkot'
    ],
    'Khyber Pakhtunkhwa': [
      'Abbottabad', 'Allai', 'Bajaur', 'Bannu', 'Battagram', 'Buner', 
      'Charsadda', 'Chitral Lower', 'Chitral Upper', 'Dera Ismail Khan', 
      'Dir Lower', 'Dir Upper', 'Hangu', 'Haripur', 'Karak', 'Khyber', 
      'Kohat', 'Kohistan Lower', 'Kohistan Upper', 'Kolai Palas', 'Kurram', 
      'Lakki Marwat', 'Lower South Waziristan', 'Malakand', 'Mansehra', 
      'Mardan', 'Mohmand', 'North Waziristan', 'Nowshera', 'Orakzai', 
      'Peshawar', 'Shangla', 'South Waziristan', 'Swabi', 'Swat', 'Tank', 
      'Torghar', 'Upper South Waziristan'
    ],
    'Balochistan': [
      'Awaran', 'Barkhan', 'Chagai', 'Chaman', 'Dera Bugti', 'Duki', 
      'Gwadar', 'Harnai', 'Hub', 'Jafarabad', 'Jhal Magsi', 'Kachhi (Bolan)', 
      'Kalat', 'Kech (Turbat)', 'Kharan', 'Khuzdar', 'Killa Abdullah', 
      'Killa Saifullah', 'Kohlu', 'Lasbela', 'Loralai', 'Mastung', 'Musakhel', 
      'Nasirabad', 'Nushki', 'Panjgur', 'Pishin', 'Quetta', 'Sherani', 
      'Sibi', 'Sohbatpur', 'Surab', 'Usta Muhammad', 'Washuk', 'Zhob', 'Ziarat'
    ],
    'Islamabad Capital Territory': [
      'Islamabad'
    ],
    'Azad Jammu & Kashmir': [
      'Bagh', 'Bhimber', 'Hattian Bala', 'Haveli', 'Kotli', 'Mirpur', 
      'Muzaffarabad', 'Neelum', 'Poonch (Rawalakot)', 'Sudhanoti'
    ],
    'Gilgit-Baltistan': [
      'Astore', 'Darel', 'Diamer', 'Ghanche', 'Ghizer', 'Gilgit', 
      'Gupis-Yasin', 'Hunza', 'Kharmang', 'Nagar', 'Rondu', 'Shigar', 
      'Skardu', 'Tangir'
    ]
  };

  /// List of 7 provinces
  static List<String> get provinces => provinceDistricts.keys.toList();

  /// Retrieve districts for a specific province
  static List<String> getDistricts(String province) {
    return provinceDistricts[province] ?? [];
  }

  /// Reverse lookup: find province for a given district
  static String getProvinceForDistrict(String district) {
    for (final entry in provinceDistricts.entries) {
      if (entry.value.any((d) => d.toLowerCase() == district.toLowerCase())) {
        return entry.key;
      }
    }
    return 'Punjab';
  }

  /// All official districts flattened
  static List<String> get allDistricts {
    final List<String> list = [];
    for (final districts in provinceDistricts.values) {
      list.addAll(districts);
    }
    list.sort();
    return list;
  }

  static const List<String> registeredInstitutes = [
    'Capital University of Science and Technology (CUST), Islamabad',
    'National University of Sciences and Technology (NUST), Islamabad',
    'COMSATS University, Islamabad',
    'Quaid-e-Azam University (QAU), Islamabad',
    'FAST National University of Computer and Emerging Sciences, Islamabad',
    'University of the Punjab (PU), Lahore',
    'Government College University (GCU), Lahore',
    'Lahore University of Management Sciences (LUMS), Lahore',
    'University of Karachi (UoK), Karachi',
    'NED University of Engineering and Technology, Karachi',
    'University of Peshawar, Peshawar',
    'Balochistan University of Information Technology, Engineering and Management Sciences (BUITEMS), Quetta',
    'Other (Unregistered Institute)'
  ];
}
