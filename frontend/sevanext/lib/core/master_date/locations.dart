// lib/core/location/locations.dart
class LocationData {
  static const Map<String, Map<String, List<String>>> locations = {
    "India": {
      "Andhra Pradesh": [
        "Visakhapatnam",
        "Vijayawada",
        "Guntur",
        "Nellore",
        "Kurnool",
      ],
      "Arunachal Pradesh": ["Itanagar", "Tawang", "Pasighat"],
      "Assam": ["Guwahati", "Silchar", "Dibrugarh", "Jorhat"],
      "Bihar": ["Patna", "Gaya", "Bhagalpur", "Muzaffarpur", "Purnia"],
      "Chhattisgarh": ["Raipur", "Bilaspur", "Durg", "Bhilai"],
      "Goa": ["Panaji", "Margao", "Vasco da Gama"],
      "Gujarat": ["Ahmedabad", "Surat", "Vadodara", "Rajkot", "Gandhinagar"],
      "Haryana": ["Gurugram", "Faridabad", "Panipat", "Ambala", "Hisar"],
      "Himachal Pradesh": ["Shimla", "Mandi", "Kullu", "Dharamshala"],
      "Jharkhand": ["Ranchi", "Jamshedpur", "Dhanbad", "Bokaro"],
      "Karnataka": ["Bengaluru", "Mysuru", "Mangaluru", "Hubballi", "Belagavi"],
      "Kerala": ["Thiruvananthapuram", "Kochi", "Kozhikode", "Thrissur"],
      "Madhya Pradesh": [
        "Indore",
        "Bhopal",
        "Gwalior",
        "Jabalpur",
        "Ujjain",
        "Sagar",
        "Rewa",
        "Satna",
        "Ratlam",
        "Burhanpur",
        "Khandwa",
        "Dhar",
        "Dewas",
        "Katni",
        "Singrauli",
        "Chhindwara",
        "Pandhurna",
        "Balaghat",
        "Hoshangabad",
        "Vidisha",
        "Kukshi",
      ],
      "Maharashtra": [
        "Mumbai",
        "Pune",
        "Nagpur",
        "Nashik",
        "Aurangabad",
        "Thane",
        "Solapur",
      ],
      "Manipur": ["Imphal"],
      "Meghalaya": ["Shillong"],
      "Mizoram": ["Aizawl"],
      "Nagaland": ["Kohima"],
      "Odisha": ["Bhubaneswar", "Cuttack", "Rourkela", "Berhampur"],
      "Punjab": ["Ludhiana", "Amritsar", "Jalandhar", "Patiala"],
      "Rajasthan": ["Jaipur", "Jodhpur", "Udaipur", "Kota", "Bikaner", "Ajmer"],
      "Sikkim": ["Gangtok"],
      "Tamil Nadu": [
        "Chennai",
        "Coimbatore",
        "Madurai",
        "Tiruchirappalli",
        "Salem",
      ],
      "Telangana": ["Hyderabad", "Warangal", "Nizamabad", "Karimnagar"],
      "Tripura": ["Agartala"],
      "Uttar Pradesh": [
        "Lucknow",
        "Kanpur",
        "Varanasi",
        "Agra",
        "Meerut",
        "Prayagraj",
      ],
      "Uttarakhand": ["Dehradun", "Haridwar", "Nainital", "Rishikesh"],
      "West Bengal": ["Kolkata", "Howrah", "Durgapur", "Asansol", "Siliguri"],
    },
  };

  static List<String> getCountries() => locations.keys.toList();

  static List<String> getStates(String country) =>
      locations[country]?.keys.toList() ?? [];

  static List<String> getDistricts(String country, String state) =>
      locations[country]?[state] ?? [];
}
