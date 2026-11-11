// lib/features/resume/presentation/screens/format/formats/government_format.dart
// ✅ FIXED: All Unicode chars replaced with ASCII for Helvetica font
// ✅ NEW: Profile photo shown in place of PHOTOGRAPH placeholder

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../resume_format_base.dart';

class GovernmentFormat extends ResumeFormatBase {
  @override
  String get id => 'government';
  @override
  String get name => 'Government / PSU';
  @override
  String get icon => '🏛️';
  @override
  String get description => 'Official Government Format';
  @override
  String get color => '#374151';
  @override
  String get styleKey => 'government';
  @override
  String get templateType => 'government';
  @override
  String get badgeText => 'Official';

  static const Color _dark = Color(0xFF1F2937);
  static const Color _border = Color(0xFF9CA3AF);
  static const Color _header = Color(0xFF374151);
  static const Color _light = Color(0xFFF9FAFB);

  @override
  String generateHtml(Map<String, dynamic> resumeData) {
    final name = getString(resumeData, 'user_info', 'full_name');
    final email = getString(resumeData, 'contact_info', 'email');
    final phone = getString(resumeData, 'contact_info', 'phone');
    final location = getLocation(resumeData);
    final dob = getString(resumeData, 'user_info', 'date_of_birth');
    final gender = getString(resumeData, 'user_info', 'gender');
    final education = getList(resumeData, 'education');
    final experience = getList(resumeData, 'experience');
    final skills = getSkills(resumeData);
    final certifications = getList(resumeData, 'certifications');
    final objective = getString(resumeData, 'career_objective', '');
    final photoUrl = pProfilePhotoUrl(resumeData);

    String eduRows = '';
    int idx = 1;
    for (final e in education) {
      final x = pMap(e);
      eduRows += '<tr><td>${idx++}</td><td>${escapeHtml(pEduTitle(x))}</td><td>${escapeHtml(pStr(x['institute']))}</td><td>${escapeHtml(pStr(x['year_of_passing'] ?? x['year']))}</td><td>${escapeHtml(pStr(x['cgpa_percentage'] ?? x['result'] ?? ''))}</td></tr>';
    }

    final photoBlock = photoUrl != null
        ? '<img src="${escapeHtml(photoUrl)}" style="width:110px;height:130px;object-fit:cover;border:2px solid #374151;background:#f3f4f6;display:inline-block;" onerror="this.style.display=\'none\'" />'
        : '<div class="photo-box">PHOTOGRAPH</div>';

    return '''
<!DOCTYPE html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>CURRICULUM VITAE - $name</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:'Times New Roman',Times,serif;background:#e5e7eb;padding:30px 20px;line-height:1.5;color:#1F2937}
.resume-container{max-width:900px;margin:0 auto;background:#fff;padding:35px 40px;box-shadow:0 4px 20px rgba(0,0,0,.1)}
.top-header{text-align:center;border-bottom:3px double #374151;padding-bottom:15px;margin-bottom:20px}
.photo-box{width:110px;height:130px;border:2px solid #374151;display:inline-block;background:#f3f4f6;line-height:130px;font-size:11px;color:#6B7280}
.title{font-size:22px;font-weight:bold;letter-spacing:3px;margin-bottom:6px;color:#1F2937}
.name-title{font-size:18px;font-weight:bold;margin-top:12px;color:#1F2937}
.section-title{font-size:14px;font-weight:bold;background:#374151;color:#fff;padding:8px 12px;margin:20px 0 12px 0;text-transform:uppercase;letter-spacing:1px}
table{width:100%;border-collapse:collapse;margin-bottom:12px}
th,td{border:1px solid #9CA3AF;padding:8px 10px;font-size:12px;text-align:left}
th{background:#F3F4F6;font-weight:bold;color:#1F2937}
.info-table td:first-child{width:35%;background:#F9FAFB;font-weight:600}
.declaration{margin-top:25px;padding:12px;background:#F9FAFB;border:1px solid #D1D5DB;font-size:12px}
.signature{margin-top:30px;text-align:right;font-size:12px}
.signature-line{display:inline-block;border-top:1px solid #374151;padding-top:4px;margin-top:30px;width:180px;text-align:center}
.skill-chip{display:inline-block;background:#E5E7EB;color:#1F2937;padding:3px 10px;border-radius:3px;font-size:11px;margin:2px;border:1px solid #9CA3AF}
</style></head><body>
<div class="resume-container">
  <div class="top-header">
    <div class="title">CURRICULUM VITAE</div>
    <div style="font-size:10px;color:#6B7280;margin-top:4px;">(As per Government / PSU Format)</div>
    <div style="margin-top:14px;">$photoBlock</div>
    <div class="name-title">${escapeHtml(name)}</div>
  </div>

  <div class="section-title">Personal Details</div>
  <table class="info-table">
    <tr><td>Full Name</td><td>${escapeHtml(name)}</td></tr>
    <tr><td>Date of Birth</td><td>${escapeHtml(dob)}</td></tr>
    <tr><td>Gender</td><td>${escapeHtml(gender)}</td></tr>
    <tr><td>Email Address</td><td>${escapeHtml(email)}</td></tr>
    <tr><td>Mobile Number</td><td>${escapeHtml(phone)}</td></tr>
    <tr><td>Permanent Address</td><td>${escapeHtml(location)}</td></tr>
  </table>

  <div class="section-title">Educational Qualifications</div>
  <table>
    <tr><th>S.No</th><th>Degree / Level</th><th>Institution</th><th>Year</th><th>Score</th></tr>
    ${eduRows.isEmpty ? '<tr><td colspan="5" style="text-align:center;">No education records</td></tr>' : eduRows}
  </table>

  <div class="section-title">Technical / Professional Skills</div>
  <div>${skills.map((s) => '<span class="skill-chip">${escapeHtml(s)}</span>').join(' ')}</div>

  <div class="section-title">Career Objective</div>
  <div style="font-size:12px;padding:10px;background:#F9FAFB;border:1px solid #D1D5DB;">${escapeHtml(objective)}</div>

  <div class="section-title">Professional Experience</div>
  ${experience.map((e) {
    final x = pMap(e);
    return '<div style="border:1px solid #D1D5DB;padding:10px;margin-bottom:8px;font-size:12px;"><strong>${escapeHtml(pStr(x['role']))}</strong> - ${escapeHtml(pStr(x['company']))}<br><em>${escapeHtml(pStr(x['start_date']))} to ${escapeHtml(pStr(x['end_date'], 'Present'))}</em><br>${escapeHtml(pStr(x['description']))}</div>';
  }).join('')}

  <div class="section-title">Certifications / Training</div>
  ${certifications.map((c) => '<div style="font-size:12px;padding:4px 0;border-bottom:1px dotted #D1D5DB;">• ${escapeHtml(pCert(pMap(c)))}</div>').join('')}

  <div class="declaration">
    <strong>DECLARATION:</strong> I hereby declare that the information furnished above is true to the best of my knowledge and belief.
  </div>
  <div class="signature">
    <div class="signature-line">Signature of Candidate</div>
  </div>
</div>
</body></html>''';
  }

  @override
  Widget buildPreview(BuildContext context, Map<String, dynamic> data) {
    final u = pMap(data['user_info']);
    final c = pMap(data['contact_info']);
    final name = pStr(u['full_name'], 'YOUR NAME');
    final email = pStr(c['email']);
    final phone = pStr(c['phone']);
    final location = pLocation(data);
    final dob = pStr(u['date_of_birth']);
    final gender = pStr(u['gender']);
    final education = pList(data['education']);
    final experience = pList(data['experience']);
    final skills = pSkills(data['skills']);
    final certs = pList(data['certifications']);
    final objective = pStr(data['career_objective']);
    final photoUrl = pProfilePhotoUrl(data);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: Container(
            color: Colors.white,
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.only(bottom: 16),
                  decoration: const BoxDecoration(
                    border:
                        Border(bottom: BorderSide(color: _header, width: 3)),
                  ),
                  child: Column(
                    children: [
                      const Text("CURRICULUM VITAE",
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 3,
                              color: _dark)),
                      const SizedBox(height: 4),
                      const Text("(As per Government / PSU Format)",
                          style: TextStyle(
                              fontSize: 10, color: Color(0xFF6B7280))),
                      const SizedBox(height: 14),
                      // ✅ Profile photo replaces the PHOTOGRAPH placeholder
                      if (photoUrl != null)
                        Container(
                          width: 100,
                          height: 120,
                          decoration: BoxDecoration(
                            border: Border.all(color: _header, width: 2),
                            color: _light,
                          ),
                          child: Image.network(
                            photoUrl,
                            fit: BoxFit.cover,
                            width: 100,
                            height: 120,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Text("PHOTOGRAPH",
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF6B7280))),
                            ),
                          ),
                        )
                      else
                        Container(
                          width: 100,
                          height: 120,
                          decoration: BoxDecoration(
                            border: Border.all(color: _header, width: 2),
                            color: _light,
                          ),
                          child: const Center(
                            child: Text("PHOTOGRAPH",
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF6B7280))),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Text(name,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _dark)),
                    ],
                  ),
                ),

                _sectionTitle("PERSONAL DETAILS"),
                _infoTable([
                  ["Full Name", name],
                  ["Date of Birth", dob],
                  ["Gender", gender],
                  ["Email Address", email],
                  ["Mobile Number", phone],
                  ["Permanent Address", location],
                ]),

                _sectionTitle("EDUCATIONAL QUALIFICATIONS"),
                if (education.isEmpty)
                  const Text("No education records",
                      style: TextStyle(fontSize: 12, color: Colors.grey))
                else
                  _educationTable(education),

                _sectionTitle("TECHNICAL / PROFESSIONAL SKILLS"),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: skills
                      .map((s) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5E7EB),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: _border),
                            ),
                            child: Text(s,
                                style: const TextStyle(
                                    fontSize: 11, color: _dark)),
                          ))
                      .toList(),
                ),

                _sectionTitle("CAREER OBJECTIVE"),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _light,
                    border: Border.all(color: _border),
                  ),
                  child: Text(objective,
                      style: const TextStyle(fontSize: 12, height: 1.5)),
                ),

                _sectionTitle("PROFESSIONAL EXPERIENCE"),
                ...experience.map((e) {
                  final x = pMap(e);
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("${pStr(x['role'])} - ${pStr(x['company'])}",
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _dark)),
                        const SizedBox(height: 4),
                        Text(
                            "${pStr(x['start_date'])} to ${pStr(x['end_date'], 'Present')}",
                            style: const TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: Color(0xFF6B7280))),
                        if (pStr(x['description']).isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(pStr(x['description']),
                              style: const TextStyle(
                                  fontSize: 11, height: 1.4)),
                        ],
                      ],
                    ),
                  );
                }),

                if (certs.isNotEmpty) ...[
                  _sectionTitle("CERTIFICATIONS / TRAINING"),
                  ...certs.map((c) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text("• ${pCert(pMap(c))}",
                            style: const TextStyle(fontSize: 11)),
                      )),
                ],

                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _light,
                    border: Border.all(color: _border),
                  ),
                  child: const Text(
                    "DECLARATION: I hereby declare that the information furnished above is true to the best of my knowledge and belief.",
                    style: TextStyle(fontSize: 11, height: 1.5),
                  ),
                ),
                const SizedBox(height: 30),
                Align(
                  alignment: Alignment.centerRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 180,
                        padding: const EdgeInsets.only(top: 4),
                        decoration: const BoxDecoration(
                          border: Border(
                              top: BorderSide(color: _header, width: 1)),
                        ),
                        child: const Text("Signature of Candidate",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, color: _dark)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String t) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.only(top: 20, bottom: 12),
        color: _header,
        child: Text(t,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1)),
      );

  Widget _infoTable(List<List<String>> rows) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: _border)),
      child: Table(
        columnWidths: const {0: FlexColumnWidth(1.2), 1: FlexColumnWidth(2)},
        border: TableBorder.all(color: _border),
        children: rows.map((r) {
          return TableRow(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                color: _light,
                child: Text(r[0],
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _dark)),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                child: Text(r[1],
                    style: const TextStyle(fontSize: 11, color: _dark)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _educationTable(List<Map<String, dynamic>> edu) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: _border)),
      child: Table(
        border: TableBorder.all(color: _border),
        children: [
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFFF3F4F6)),
            children: [
              _th("S.No"),
              _th("Degree"),
              _th("Institution"),
              _th("Year"),
              _th("Score"),
            ],
          ),
          ...edu.asMap().entries.map((entry) {
            final x = entry.value;
            return TableRow(
              children: [
                _td("${entry.key + 1}"),
                _td(pEduTitle(x)),
                _td(pStr(x['institute'])),
                _td(pStr(x['year_of_passing'] ?? x['year'])),
                _td(pStr(x['cgpa_percentage'] ?? x['result'] ?? '')),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _th(String t) => Padding(
        padding: const EdgeInsets.all(8),
        child: Text(t,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: _dark)),
      );

  Widget _td(String t) => Padding(
        padding: const EdgeInsets.all(8),
        child:
            Text(t, style: const TextStyle(fontSize: 11, color: _dark)),
      );

  @override
  pw.Widget buildPdfContent(
    Map<String, dynamic> data,
    PdfPageFormat pageFormat,
  ) {
    final accent = pdfColor(color.isEmpty ? '#374151' : color);
    final dark = pdfColor('#1F2937');
    final border = pdfColor('#9CA3AF');
    final light = pdfColor('#F9FAFB');

    final u = pdfMap(data['user_info']);
    final c = pdfMap(data['contact_info']);
    final name = pdfStr(u['full_name'], 'YOUR NAME');
    final email = pdfStr(c['email']);
    final phone = pdfStr(c['phone']);
    final location = pdfLocation(data);
    final dob = pdfStr(u['date_of_birth']);
    final gender = pdfStr(u['gender']);
    final edu = pdfList(data['education']);
    final exp = pdfList(data['experience']);
    final skills = pdfSkills(data['skills']);
    final certs = pdfList(data['certifications']);
    final objective = pdfStr(data['career_objective']);

    final eduRows = <List<String>>[];
    for (var i = 0; i < edu.length; i++) {
      final e = edu[i];
      eduRows.add([
        '${i + 1}',
        pdfSafe(pdfStr(e['degree'], pdfStr(e['level'], 'Education'))),
        pdfSafe(pdfStr(e['institute'])),
        pdfSafe(pdfStr(e['year_of_passing'] ?? e['year'])),
        pdfSafe(pdfStr(e['cgpa_percentage'] ?? e['result'])),
      ]);
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.only(bottom: 12),
          decoration: pw.BoxDecoration(
            border: pw.Border(
                bottom: pw.BorderSide(color: accent, width: 2.5)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text('CURRICULUM VITAE',
                  style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 2,
                      color: dark)),
              pw.SizedBox(height: 3),
              pw.Text('(As per Government / PSU Format)',
                  style: const pw.TextStyle(
                      fontSize: 9, color: PdfColors.grey600)),
              pw.SizedBox(height: 12),
              // ✅ Profile photo (or empty box) in header
              pw.Container(
                width: 90,
                height: 110,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: accent, width: 1.5),
                ),
                child: pw.Center(
                  child: pdfProfilePhoto(
                    data: data,
                    size: 86,
                    borderColor: accent,
                    borderWidth: 0,
                  ),
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Text(pdfSafe(name),
                  style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: dark)),
            ],
          ),
        ),
        pw.SizedBox(height: 14),

        pdfGovSectionTitle('PERSONAL DETAILS', accent),
        pdfGovInfoTable([
          ['Full Name', pdfSafe(name)],
          ['Date of Birth', pdfSafe(dob)],
          ['Gender', pdfSafe(gender)],
          ['Email Address', pdfSafe(email)],
          ['Mobile Number', pdfSafe(phone)],
          ['Permanent Address', pdfSafe(location)],
        ], border, light),

        pdfGovSectionTitle('EDUCATIONAL QUALIFICATIONS', accent),
        pw.TableHelper.fromTextArray(
          headers: const ['#', 'Degree', 'Institution', 'Year', 'Score'],
          data: eduRows.isEmpty
              ? [
                  ['-', 'No education records', '-', '-', '-']
                ]
              : eduRows,
          headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: dark),
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerDecoration: pw.BoxDecoration(color: light),
          border: pw.TableBorder.all(color: border),
        ),

        if (skills.isNotEmpty) ...[
          pdfGovSectionTitle('TECHNICAL / PROFESSIONAL SKILLS', accent),
          pw.Wrap(
            spacing: 4,
            runSpacing: 4,
            children: skills
                .map((s) => pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: pw.BoxDecoration(
                        color: light,
                        border: pw.Border.all(color: border, width: 0.5),
                      ),
                      child:
                          pw.Text(pdfSafe(s), style: const pw.TextStyle(fontSize: 9)),
                    ))
                .toList(),
          ),
        ],

        if (objective.isNotEmpty) ...[
          pdfGovSectionTitle('CAREER OBJECTIVE', accent),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: light,
              border: pw.Border.all(color: border, width: 0.5),
            ),
            child: pw.Text(pdfSafe(objective),
                style: const pw.TextStyle(fontSize: 10, lineSpacing: 2)),
          ),
        ],

        if (exp.isNotEmpty) ...[
          pdfGovSectionTitle('PROFESSIONAL EXPERIENCE', accent),
          ...exp.map((e) => pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                margin: const pw.EdgeInsets.only(bottom: 6),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: border, width: 0.5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      pdfSafe(
                          '${pdfStr(e["role"])} - ${pdfStr(e["company"])}'),
                      style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: dark),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      pdfSafe(
                          '${pdfStr(e["start_date"])} to ${pdfStr(e["end_date"], "Present")}'),
                      style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey700,
                          fontStyle: pw.FontStyle.italic),
                    ),
                    if (pdfStr(e['description']).isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(pdfSafe(pdfStr(e['description'])),
                          style: const pw.TextStyle(
                              fontSize: 9, lineSpacing: 1.5)),
                    ],
                  ],
                ),
              )),
        ],

        if (certs.isNotEmpty) ...[
          pdfGovSectionTitle('CERTIFICATIONS / TRAINING', accent),
          ...certs.map((crt) => pw.Text(
              '- ${pdfSafe(pdfStr(crt["name"]))}${pdfStr(crt["issuer"]).isNotEmpty ? " - ${pdfSafe(pdfStr(crt["issuer"]))}" : ""}',
              style: const pw.TextStyle(fontSize: 9))),
        ],

        pw.SizedBox(height: 20),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: light,
            border: pw.Border.all(color: border, width: 0.5),
          ),
          child: pw.Text(
            'DECLARATION: I hereby declare that the information furnished above is true to the best of my knowledge and belief.',
            style: const pw.TextStyle(fontSize: 9, lineSpacing: 1.5),
          ),
        ),
        pw.SizedBox(height: 30),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                width: 180,
                padding: const pw.EdgeInsets.only(top: 4),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                      top: pw.BorderSide(color: accent, width: 0.5)),
                ),
                child: pw.Text('Signature of Candidate',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontSize: 9, color: dark)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}