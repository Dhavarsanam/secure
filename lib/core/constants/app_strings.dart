class AppStrings {
  // App
  static const String appName = 'SecureRide';
  static const String appTagline = 'Safe. Private. Connected.';

  // Auth
  static const String login = 'Login';
  static const String signup = 'Sign Up';
  static const String logout = 'Logout';
  static const String email = 'Email';
  static const String password = 'Password';
  static const String confirmPassword = 'Confirm Password';
  static const String fullName = 'Full Name';
  static const String phoneNumber = 'Phone Number';
  static const String forgotPassword = 'Forgot Password?';
  static const String resetPassword = 'Reset Password';
  static const String dontHaveAccount = "Don't have an account? ";
  static const String alreadyHaveAccount = 'Already have an account? ';
  static const String signUpNow = 'Sign Up Now';
  static const String loginHere = 'Login Here';

  // Home
  static const String home = 'Home';
  static const String myTrips = 'My Trips';
  static const String joinTrip = 'Join Trip';
  static const String liveLocation = 'Live Location';
  static const String contacts = 'Contacts';
  static const String settings = 'Settings';
  static const String sos = 'SOS';

  // Trip
  static const String createTrip = 'Create Trip';
  static const String tripDetails = 'Trip Details';
  static const String startLocation = 'Start Location';
  static const String destination = 'Destination';
  static const String travelDate = 'Travel Date';
  static const String passengerType = 'Passenger Type';
  static const String vehicleType = 'Vehicle Type';
  static const String availableSeats = 'Available Seats';
  static const String tripCode = 'Trip Code';
  static const String enterTripCode = 'Enter Trip Code';
  static const String joinNow = 'Join Now';
  static const String createNow = 'Create Trip';
  static const String noTripsFound = 'No trips found';
  static const String activeTrips = 'Active Trips';
  static const String completedTrips = 'Completed Trips';

  // Passenger Types
  static const List<String> passengerTypes = [
    'Solo',
    'Family',
    'Group',
    'Women Only',
    'Corporate',
  ];

  // Vehicle Types
  static const List<String> vehicleTypes = [
    'Car',
    'Bike',
    'Auto',
    'Van',
    'Bus',
    'SUV',
  ];

  // Map
  static const String map = 'Map';
  static const String routePlanning = 'Route Planning';
  static const String searchLocation = 'Search Location';
  static const String currentLocation = 'Current Location';
  static const String shareLocation = 'Share Location';
  static const String stopSharing = 'Stop Sharing';

  // Contacts
  static const String approvedContacts = 'Approved Contacts';
  static const String addContact = 'Add Contact';
  static const String removeContact = 'Remove Contact';
  static const String noContacts = 'No approved contacts yet';
  static const String contactEmail = 'Contact Email';

  // SOS
  static const String sosTitle = 'Emergency SOS';
  static const String sosMessage = 'Send Emergency Alert';
  static const String sosConfirm = 'Are you sure you want to send SOS?';
  static const String sosActive = 'SOS Active - Sending updates...';
  static const String sosSent = 'SOS Alert Sent!';
  static const String cancelSos = 'Cancel SOS';
  static const String sosDescription =
      'This will send your current location and trip details to all approved contacts via email.';

  // Errors
  static const String errorGeneric = 'Something went wrong. Please try again.';
  static const String errorNetwork = 'No internet connection.';
  static const String errorInvalidEmail = 'Please enter a valid email.';
  static const String errorWeakPassword =
      'Password must be at least 6 characters.';
  static const String errorPasswordMismatch = 'Passwords do not match.';
  static const String errorEmptyField = 'This field cannot be empty.';
  static const String errorLocationPermission =
      'Location permission is required.';
  static const String errorTripNotFound = 'Trip not found. Check the code.';

  // Success
  static const String successTripCreated = 'Trip created successfully!';
  static const String successTripJoined = 'Joined trip successfully!';
  static const String successContactAdded = 'Contact added successfully!';
  static const String successSosSent = 'SOS alert sent to all contacts!';
  static const String successPasswordReset = 'Password reset email sent!';
}
