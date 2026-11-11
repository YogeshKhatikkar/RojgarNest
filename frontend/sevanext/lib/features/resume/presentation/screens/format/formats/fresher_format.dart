// lib/features/resume/presentation/screens/format/formats/fresher_format.dart
// ✅ Teal education-first layout with profile photo support

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../resume_format_base.dart';

class FresherFormat extends ResumeFormatBase {
  @override
  String get id => 'fresher';
  @override
  String get name => 'Fresher / Entry Level';
  @override
  String get icon => '🎓';
  @override
  String get description => 'Perfect for freshers & interns';
  @override
  String get color => '#00897B';
  @override
  String get styleKey => 'fresher';
  @override
  String get templateType => 'fresher';
  @override
  String get badgeText => 'Fresher';

  static const Color _teal = Color(0xFF00897B);
  static const Color _teal2 = Color(0xFF26A69A);
  static const Color _bg = Color(0xFFE0F2F1);
  static const Color _bodyBg = Color(0xFFF1FDFB);

  @override
  String generateHtml(Map<String, dynamic> resumeData) {
    final name = getString(resumeData, 'user_info', 'full_name');
    final email = getString(resumeData, 'contact_info', 'email');
    final phone = getString(resumeData, 'contact_info', 'phone');
    final location = getLocation(resumeData);
    final objective = getString(resumeData, 'career_objective', '');
    final education = getList(resumeData, 'education');
    final experience = getList(resumeData, 'experience');
    final skills = getSkills(resumeData);
    final certifications = getList(resumeData, 'certifications');
    final projects = getList(resumeData, 'projects');
    final designation = pDesignation(resumeData);
    final photoUrl = pProfilePhotoUrl(resumeData);

    final desigHtml = designation.isNotEmpty
        ? '<div style="font-size:12px;color:rgba(255,255,255,.85);">${escapeHtml(designation)}</div>'
        : '';

    final photoHtml = photoUrl != null
        ? '<img src="${escapeHtml(photoUrl)}" style="width:90px;height:90px;border-radius:50%;object-fit:cover;border:3px solid #fff;margin-bottom:10px;display:block;margin-left:auto;margin-right:auto;" onerror="this.style.display=\'none\'" />'
        : '';

    return '''
<!DOCTYPE html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>$name</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:'Inter','Segoe UI',sans-serif;background:#E0F2F1;padding:30px 20px;line-height:1.6;color:#1F2937}
.resume-container{max-width:1000px;margin:0 auto;background:#F1FDFB;border-radius:16px;overflow:hidden;box-shadow:0 10px 40px rgba(0,0,0,.08);display:flex}
.sidebar{width:32%;background:#E0F2F1;padding:30px 22px}
.main{width:68%;padding:30px 32px}
.header{background:linear-gradient(135deg,#00897B 0%,#26A69A 100%);color:#fff;padding:24px;border-radius:12px;text-align:center;margin-bottom:20px}
.name{font-size:26px;font-weight:800}
.section-title{font-size:13px;font-weight:700;color:#00897B;text-transform:uppercase;letter-spacing:1.2px;margin:20px 0 12px 0;padding-bottom:6px;border-bottom:2px solid #26A69A}
.section-title:first-child{margin-top:0}
.skill-item{margin-bottom:8px}
.skill-bar{height:4px;background:#00897B;border-radius:2px;margin-top:4px}
.skill-name{font-size:11px;font-weight:600}
.card-item{padding:12px;margin-bottom:10px;background:#fff;border-radius:10px;border-left:4px solid #00897B}
.card-title{font-size:14px;font-weight:700;color:#00897B}
.card-subtitle{font-size:11px;color:#6B7280;margin-top:2px}
.summary-text{font-size:13px;line-height:1.7;padding:14px;background:#fff;border-left:4px solid #26A69A;border-radius:8px}
</style></head><body>
<div class="resume-container">
  <div class="sidebar">
    <div class="header">
      $photoHtml
      <div class="name">${escapeHtml(name)}</div>
      $desigHtml
      <div style="font-size:11px;margin-top:10px;line-height:1.6;">
        ${email.isNotEmpty ? '📧 ${escapeHtml(email)}<br>' : ''}
        ${phone.isNotEmpty ? '📞 ${escapeHtml(phone)}<br>' : ''}
        ${location.isNotEmpty ? '📍 ${escapeHtml(location)}' : ''}
      </div>
    </div>
    <div class="section-title">Key Skills</div>
    ${skills.map((s) => '<div class="skill-item"><div class="skill-name">${escapeHtml(s)}</div><div class="skill-bar"></div></div>').join('')}
    ${certifications.isNotEmpty ? '<div class="section-title">Certifications</div>' : ''}
    ${certifications.map((c) => '<div style="font-size:11px;padding:4px 0;">• ${escapeHtml(pCert(pMap(c)))}</div>').join('')}
  </div>
  <div class="main">
    ${objective.isNotEmpty ? '<div class="section-title">Career Objective</div><div class="summary-text">${escapeHtml(objective)}</div>' : ''}

    ${education.isNotEmpty ? '<div class="section-title" style="margin-top:20px;">Education</div>' : ''}
    ${education.map((e) {
      final x = pMap(e);
      return '<div class="card-item"><div class="card-title">${escapeHtml(pEduTitle(x))}</div><div class="card-subtitle">${escapeHtml(pEduSubtitle(x))}</div></div>';
    }).join('')}

    ${projects.isNotEmpty ? '<div class="section-title" style="margin-top:20px;">Projects</div>' : ''}
    ${projects.map((p) {
      final x = pMap(p);
      return '<div class="card-item"><div class="card-title">${escapeHtml(pStr(x['title']))}</div><div style="font-size:12px;margin-top:4px;">${escapeHtml(pStr(x['description']))}</div></div>';
    }).join('')}

    ${experience.isNotEmpty ? '<div class="section-title" style="margin-top:20px;">Internships / Experience</div>' : ''}
    ${experience.map((e) {
      final x = pMap(e);
      return '<div class="card-item"><div class="card-title">${escapeHtml(pStr(x['role']))}</div><div class="card-subtitle">${escapeHtml(pStr(x['company']))} | ${escapeHtml(pStr(x['start_date']))} - ${escapeHtml(pStr(x['end_date'], 'Present'))}</div></div>';
    }).join('')}
  </div>
</div>
</body></html>''';
  }

  @override
  Widget buildPreview(BuildContext context, Map<String, dynamic> data) {
    final u = pMap(data['user_info']);
    final c = pMap(data['contact_info']);
    final name = pStr(u['full_name'], 'Your Name');
    final email = pStr(c['email']);
    final phone = pStr(c['phone']);
    final location = pLocation(data);
    final objective = pStr(data['career_objective']);
    final edu = pList(data['education']);
    final exp = pList(data['experience']);
    final skills = pSkills(data['skills']);
    final certs = pList(data['certifications']);
    final projects = pList(data['projects']);
    final designation = pDesignation(data);
    final photoUrl = pProfilePhotoUrl(data);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: Container(
            color: _bodyBg,
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: constraints.maxWidth * 0.32,
                    color: _bg,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_teal, _teal2],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              if (photoUrl != null) ...[
                                pProfilePhoto(
                                  url: photoUrl,
                                  size: 78,
                                  borderColor: Colors.white,
                                  borderWidth: 2.5,
                                ),
                                const SizedBox(height: 10),
                              ] else ...[
                                pInitialsAvatar(
                                  name: name,
                                  size: 78,
                                  bgColor: _teal,
                                ),
                                const SizedBox(height: 10),
                              ],
                              Text(name,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                              if (designation.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(designation,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.white70)),
                              ],
                              const SizedBox(height: 10),
                              if (email.isNotEmpty)
                                Text("📧 $email",
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.white)),
                              if (phone.isNotEmpty)
                                Text("📞 $phone",
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.white)),
                              if (location.isNotEmpty)
                                Text("📍 $location",
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.white)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _sideTitle("KEY SKILLS"),
                        ...skills.map((s) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Container(
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: _teal,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                        if (certs.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          _sideTitle("CERTIFICATIONS"),
                          ...certs.map((c) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text("• ${pCert(pMap(c))}",
                                    style: const TextStyle(fontSize: 11)),
                              )),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      color: _bodyBg,
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (objective.isNotEmpty) ...[
                            _mainTitle("CAREER OBJECTIVE"),
                            pInfoBox(objective,
                                bg: Colors.white,
                                leftBorder: _teal,
                                textStyle: const TextStyle(
                                    fontSize: 12, height: 1.6)),
                            const SizedBox(height: 18),
                          ],
                          if (edu.isNotEmpty) ...[
                            _mainTitle("EDUCATION"),
                            ...edu.map((e) => _eduCard(pMap(e))),
                            const SizedBox(height: 18),
                          ],
                          if (projects.isNotEmpty) ...[
                            _mainTitle("PROJECTS"),
                            ...projects.map((p) => _projCard(pMap(p))),
                            const SizedBox(height: 18),
                          ],
                          if (exp.isNotEmpty) ...[
                            _mainTitle("INTERNSHIPS / EXPERIENCE"),
                            ...exp.map((e) => _expCard(pMap(e))),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sideTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _teal,
                letterSpacing: 1.2)),
      );

  Widget _mainTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _teal,
                    letterSpacing: 1.2)),
            const SizedBox(height: 4),
            Container(height: 2, width: 40, color: _teal2),
          ],
        ),
      );

  Widget _eduCard(Map<String, dynamic> e) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pEduTitle(e),
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.bold, color: _teal)),
            const SizedBox(height: 2),
            if (pEduSubtitle(e).isNotEmpty)
              Text(pEduSubtitle(e),
                  style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ],
        ),
      );

  Widget _projCard(Map<String, dynamic> p) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pStr(p['title'], 'Project'),
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.bold, color: _teal)),
            if (pStr(p['description']).isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(pStr(p['description']),
                  style: const TextStyle(fontSize: 11, height: 1.5)),
            ],
          ],
        ),
      );

  Widget _expCard(Map<String, dynamic> e) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pStr(e['role'], 'Role'),
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.bold, color: _teal)),
            const SizedBox(height: 2),
            Text(
                "${pStr(e['company'])} | ${pStr(e['start_date'])} - ${pStr(e['end_date'], 'Present')}",
                style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ],
        ),
      );

  @override
  pw.Widget buildPdfContent(
    Map<String, dynamic> data,
    PdfPageFormat pageFormat,
  ) {
    final teal = pdfColor(color.isEmpty ? '#00897B' : color);
    final teal2 = pdfColor('#26A69A');
    final bg = pdfColor('#E0F2F1');
    final bodyBg = pdfColor('#F1FDFB');

    final u = pdfMap(data['user_info']);
    final c = pdfMap(data['contact_info']);
    final name = pdfStr(u['full_name'], 'Your Name');
    final desig = pdfDesignation(data);
    final email = pdfStr(c['email']);
    final phone = pdfStr(c['phone']);
    final location = pdfLocation(data);
    final objective = pdfStr(data['career_objective']);
    final edu = pdfList(data['education']);
    final exp = pdfList(data['experience']);
    final skills = pdfSkills(data['skills']);
    final certs = pdfList(data['certifications']);
    final projects = pdfList(data['projects']);

    return pw.Container(
      color: bodyBg,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            width: 180,
            color: bg,
            padding: const pw.EdgeInsets.all(16),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    gradient: pw.LinearGradient(
                      colors: [teal, teal2],
                      begin: pw.Alignment.topLeft,
                      end: pw.Alignment.bottomRight,
                    ),
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pdfProfilePhoto(
                        data: data,
                        size: 76,
                        borderColor: PdfColors.white,
                        borderWidth: 2.5,
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(pdfSafe(name),
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white)),
                      if (desig.isNotEmpty) ...[
                        pw.SizedBox(height: 3),
                        pw.Text(pdfSafe(desig),
                            style: const pw.TextStyle(
                                fontSize: 9, color: PdfColors.white)),
                      ],
                      pw.SizedBox(height: 8),
                      if (phone.isNotEmpty)
                        pw.Text(pdfSafe(phone),
                            style: const pw.TextStyle(
                                fontSize: 8, color: PdfColors.white)),
                      if (email.isNotEmpty)
                        pw.Text(pdfSafe(email),
                            style: const pw.TextStyle(
                                fontSize: 8, color: PdfColors.white)),
                      if (location.isNotEmpty)
                        pw.Text(pdfSafe(location),
                            style: const pw.TextStyle(
                                fontSize: 8, color: PdfColors.white)),
                    ],
                  ),
                ),
                if (skills.isNotEmpty) ...[
                  pw.SizedBox(height: 14),
                  pdfSideTitle('KEY SKILLS', teal),
                  ...skills.take(12).map((s) => pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 4),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(pdfSafe(s),
                                style: const pw.TextStyle(fontSize: 9)),
                            pw.SizedBox(height: 2),
                            pw.Container(
                              height: 3,
                              decoration: pw.BoxDecoration(
                                color: teal,
                                borderRadius: pw.BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
                if (certs.isNotEmpty) ...[
                  pw.SizedBox(height: 14),
                  pdfSideTitle('CERTIFICATIONS', teal),
                  ...certs.take(6).map((crt) => pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 3),
                        child: pw.Text('- ${pdfSafe(pdfStr(crt["name"]))}',
                            style: const pw.TextStyle(fontSize: 8)),
                      )),
                ],
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Container(
              color: bodyBg,
              padding: const pw.EdgeInsets.all(20),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (objective.isNotEmpty) ...[
                    pdfMainTitle('CAREER OBJECTIVE', teal),
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        border: pw.Border(
                            left: pw.BorderSide(color: teal, width: 3)),
                      ),
                      child: pw.Text(pdfSafe(objective),
                          style: const pw.TextStyle(
                              fontSize: 10, lineSpacing: 2)),
                    ),
                    pw.SizedBox(height: 14),
                  ],
                  if (edu.isNotEmpty) ...[
                    pdfMainTitle('EDUCATION', teal),
                    ...edu.take(5).map((e) => pw.Container(
                          margin: const pw.EdgeInsets.only(bottom: 6),
                          padding: const pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.white,
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                pdfSafe(pdfStr(e['degree'],
                                    pdfStr(e['level'], 'Education'))),
                                style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold,
                                    color: teal),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                pdfSafe(
                                  [
                                    pdfStr(e['institute']),
                                    pdfStr(e['year_of_passing'],
                                        pdfStr(e['year'])),
                                  ].where((x) => x.isNotEmpty).join(' | '),
                                ),
                                style: const pw.TextStyle(fontSize: 9),
                              ),
                            ],
                          ),
                        )),
                    pw.SizedBox(height: 10),
                  ],
                  if (projects.isNotEmpty) ...[
                    pdfMainTitle('PROJECTS', teal),
                    ...projects.take(4).map((p) => pw.Container(
                          margin: const pw.EdgeInsets.only(bottom: 6),
                          padding: const pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.white,
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(pdfSafe(pdfStr(p['title'], 'Project')),
                                  style: pw.TextStyle(
                                      fontSize: 10,
                                      fontWeight: pw.FontWeight.bold,
                                      color: teal)),
                              if (pdfStr(p['description']).isNotEmpty) ...[
                                pw.SizedBox(height: 3),
                                pw.Text(pdfSafe(pdfStr(p['description'])),
                                    style: const pw.TextStyle(
                                        fontSize: 9, lineSpacing: 1.4)),
                              ],
                            ],
                          ),
                        )),
                    pw.SizedBox(height: 10),
                  ],
                  if (exp.isNotEmpty) ...[
                    pdfMainTitle('INTERNSHIPS / EXPERIENCE', teal),
                    ...exp.take(3).map((e) => pw.Container(
                          margin: const pw.EdgeInsets.only(bottom: 6),
                          padding: const pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.white,
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(pdfSafe(pdfStr(e['role'], 'Role')),
                                  style: pw.TextStyle(
                                      fontSize: 10,
                                      fontWeight: pw.FontWeight.bold,
                                      color: teal)),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                pdfSafe(
                                  '${pdfStr(e["company"])} | ${pdfStr(e["start_date"])} - ${pdfStr(e["end_date"], "Present")}',
                                ),
                                style: const pw.TextStyle(fontSize: 9),
                              ),
                            ],
                          ),
                        )),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}