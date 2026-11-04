/// Value object representing a resolved Focal Person routing destination.
class FocalPersonRoute {
  final String assignedName;
  final String assignedEmail;
  final String routingType;

  const FocalPersonRoute({
    required this.assignedName,
    required this.assignedEmail,
    required this.routingType,
  });
}

/// Open/Closed Principle (OCP) interface for routing strategies.
/// New strategies can be introduced without modifying existing client modules.
abstract class IRoutingStrategy {
  /// Evaluates and assigns the focal person routing route based on volunteer metrics.
  FocalPersonRoute route({
    required String role,
    String? district,
    String? instituteName,
  });
}

/// Concrete strategy for Institutional (Registered) student routing.
class InstitutionalRoutingStrategy implements IRoutingStrategy {
  @override
  FocalPersonRoute route({
    required String role,
    String? district,
    String? instituteName,
  }) {
    final cleanInstitute = instituteName ?? 'Registered University';
    
    if (cleanInstitute.contains('Capital University of Science and Technology (CUST)')) {
      return const FocalPersonRoute(
        assignedName: 'Dr. Daud Arshad (CUST VIS Lead)',
        assignedEmail: 'cust_focal@eoto.pk',
        routingType: 'Institutional (Registered)',
      );
    }
    
    if (cleanInstitute.contains('National University of Sciences and Technology (NUST)')) {
      return const FocalPersonRoute(
        assignedName: 'Dr. Sajid Ali (NUST Service Learning Director)',
        assignedEmail: 'nust_focal@eoto.pk',
        routingType: 'Institutional (Registered)',
      );
    }

    if (cleanInstitute.contains('FAST National University')) {
      return const FocalPersonRoute(
        assignedName: 'Dr. Fareeha Raza (FAST VIS Lead)',
        assignedEmail: 'fast_focal@eoto.pk',
        routingType: 'Institutional (Registered)',
      );
    }

    if (cleanInstitute.contains('COMSATS University')) {
      return const FocalPersonRoute(
        assignedName: 'Prof. Mukhtar Ahmed (COMSATS VIS Coordinator)',
        assignedEmail: 'comsats_focal@eoto.pk',
        routingType: 'Institutional (Registered)',
      );
    }

    if (cleanInstitute.contains('University of the Punjab (PU)')) {
      return const FocalPersonRoute(
        assignedName: 'Dr. Ahmed (PU VIS Lead)',
        assignedEmail: 'pu_focal@eoto.pk',
        routingType: 'Institutional (Registered)',
      );
    }
    
    // Extensible dynamic mapping for other registered institutions
    final shortName = cleanInstitute
        .replaceAll('Capital University of Science and Technology (CUST)', 'CUST')
        .split(',')[0]
        .trim();
        
    return FocalPersonRoute(
      assignedName: 'Prof. Ahmed ($shortName Representative)',
      assignedEmail: '${shortName.toLowerCase().replaceAll(' ', '_')}_focal@eoto.pk',
      routingType: 'Institutional (Registered)',
    );
  }
}

/// Concrete strategy for District Officer / Community routing.
/// Applies to community volunteers or students from unregistered ("Other") institutions.
class DistrictOfficerRoutingStrategy implements IRoutingStrategy {
  @override
  FocalPersonRoute route({
    required String role,
    String? district,
    String? instituteName,
  }) {
    final cleanDistrict = district ?? 'Islamabad (ICT)';
    
    if (cleanDistrict == 'Islamabad (ICT)') {
      return const FocalPersonRoute(
        assignedName: 'Mr. Danish Abbas (NCHD Islamabad District Officer)',
        assignedEmail: 'islamabad_officer@eoto.pk',
        routingType: 'District Officer (Unregistered/Community)',
      );
    }
    
    // Dynamic mapping for other districts across Pakistan
    final strippedDistrict = cleanDistrict.replaceAll(' (ICT)', '').trim();
    return FocalPersonRoute(
      assignedName: 'Mr. Khan (NCHD $strippedDistrict Officer)',
      assignedEmail: '${strippedDistrict.toLowerCase().replaceAll(' ', '_')}_officer@eoto.pk',
      routingType: 'District Officer (Unregistered/Community)',
    );
  }
}

/// Router context coordinator determining which strategy to employ.
class EotoRouter {
  /// Dynamic strategy resolver applying OCP.
  static FocalPersonRoute resolveRoute({
    required String role,
    String? district,
    String? instituteName,
  }) {
    final bool isStudent = role == 'student';
    final bool isOtherInstitute = instituteName == 'Other (Unregistered Institute)' || instituteName == 'NONE';

    IRoutingStrategy strategy;
    if (isStudent && !isOtherInstitute) {
      strategy = InstitutionalRoutingStrategy();
    } else {
      strategy = DistrictOfficerRoutingStrategy();
    }

    return strategy.route(
      role: role,
      district: district,
      instituteName: instituteName,
    );
  }
}
