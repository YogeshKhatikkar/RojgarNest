// lib/features/resume/presentation/screens/format/formats/modern_format.dart
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../resume_format_base.dart';

class ModernFormat extends ResumeFormatBase {
  @override
  String get id => 'modern';
  @override
  String get name => 'Modern Creative';
  @override
  String get icon => '🎨';
  @override
  String get description => 'Creative & Bold Design';
  @override
  String get color => '#7C3AED';
  @override
  String get styleKey => 'modern';
  @override
  String get templateType => 'modern';
  @override
  String get badgeText => 'Creative';

  static const Color _violet = Color(0xFF7C3AED);
  static const Color _pink = Color(0xFFEC4899);
  static const Color _dark = Color(0xFF1F2937);
  static const Color _light = Color(0xFFF9FAFB);

  @override
  String generateHtml(Map<String, dynamic> resumeData) {
    final name = getString(resumeData, 'user_info', 'full_name');
    final email = getString(resumeData, 'contact_info', 'email');
    final phone = getString(resumeData, 'contact_info', 'phone');
    final location = getLocation(resumeData);
    final summary = getString(resumeData, 'professional_summary', '');
    final education = getList(resumeData, 'education');
    final experience = getList(resumeData, 'experience');
    final skills = getSkills(resumeData);
    final certifications = getList(resumeData, 'certifications');
    final projects = getList(resumeData, 'projects');
    final designation = pDesignation(resumeData);
    final photoUrl = pProfilePhotoUrl(resumeData);

    final desigHtml = designation.isNotEmpty
        ? '<div style="font-size:13px;color:rgba(255,255,255,0.85);">${escapeHtml(designation)}</div>'
        : '';

    final photoHtml = photoUrl != null
        ? '<img src="${escapeHtml(photoUrl)}" style="width:100px;height:100px;border-radius:50%;object-fit:cover;border:3px solid #fff;margin-bottom:12px;" onerror="this.style.display=\'none\'" />'
        : '';

    return '''
<!DOCTYPE html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:'Inter','Segoe UI',sans-serif;background:#f3f4f6;padding:30px 20px;line-height:1.6}
.resume-container{max-width:1000px;margin:0 auto;background:#fff;border-radius:24px;overflow:hidden;box-shadow:0 20px 60px rgba(0,0,0,.15);display:flex;flex-direction:column}
.top-header{background:linear-gradient(135deg,#7C3AED 0%,#EC4899 100%);color:#fff;padding:35px 40px;position:relative}
.top-header::after{content:'';position:absolute;right:-50px;top:-50px;width:200px;height:200px;background:rgba(255,255,255,.1);border-radius:50%}
.name{font-size:34px;font-weight:800;letter-spacing:-0.5px}
.contact-row{display:flex;flex-wrap:wrap;gap:18px;margin-top:12px;font-size:13px;color:rgba(255,255,255,.9)}
.contact-row span{display:inline-flex;align-items:center;gap:6px}
.body{display:flex}
.left{width:32%;background:#F9FAFB;padding:30px 24px;border-right:1px solid #E5E7EB}
.right{width:68%;padding:30px 32px}
.section-title{font-size:14px;font-weight:700;color:#7C3AED;text-transform:uppercase;letter-spacing:1.5px;margin:20px 0 12px 0;border-bottom:2px solid #EC4899;padding-bottom:6px}
.section-title:first-child{margin-top:0}
.card-item{padding:14px;margin-bottom:12px;background:#fff;border-radius:12px;border-left:4px solid #7C3AED;box-shadow:0 2px 8px rgba(0,0,0,.04)}
.card-title{font-size:15px;font-weight:700;color:#1F2937}
.card-subtitle{font-size:12px;color:#6B7280;margin-top:2px}
.summary-text{font-size:13px;line-height:1.7;padding:16px;background:#fff;border-radius:12px;border-left:4px solid #EC4899}
.skill-chip{display:inline-block;background:#EDE9FE;color:#7C3AED;padding:5px 12px;border-radius:20px;font-size:12px;font-weight:600;margin:3px}
.cert-item{font-size:12px;color:#374151;margin-bottom:6px;padding-left:14px;position:relative}
.cert-item::before{content:'▸';position:absolute;left:0;color:#EC4899;font-weight:bold}
</style></head><body>
<div class="resume-container">
  <div class="top-header">
    $photoHtml
    <div class="name">${escapeHtml(name)}</div>
    $desigHtml
    <div class="contact-row">
      ${email.isNotEmpty ? '<span>📧 ${escapeHtml(email)}</span>' : ''}
      ${phone.isNotEmpty ? '<span>📞 ${escapeHtml(phone)}</span>' : ''}
      ${location.isNotEmpty ? '<span>📍 ${escapeHtml(location)}</span>' : ''}
    </div>
  </div>
  <div class="body">
    <div class="left">
      <div class="section-title">Skills</div>
      <div>${skills.map((s) => '<span class="skill-chip">${escapeHtml(s)}</span>').join(' ')}</div>
      <div class="section-title">Education</div>
      ${education.map((e) {
        final x = pMap(e);
        return '<div class="card-item"><div class="card-title" style="font-size:13px;">${escapeHtml(pEduTitle(x))}</div><div class="card-subtitle">${escapeHtml(pEduSubtitle(x))}</div></div>';
      }).join('')}
      ${certifications.isNotEmpty ? '<div class="section-title">Certifications</div>' : ''}
      ${certifications.map((c) => '<div class="cert-item">${escapeHtml(pCert(pMap(c)))}</div>').join('')}
    </div>
    <div class="right">
      ${summary.isNotEmpty ? '<div class="section-title">About Me</div>' : ''}
      ${summary.isNotEmpty ? '<div class="summary-text">${escapeHtml(summary)}</div>' : ''}
      ${experience.isNotEmpty ? '<div class="section-title">Experience</div>' : ''}
      ${experience.map((e) {
        final x = pMap(e);
        return '<div class="card-item"><div class="card-title">${escapeHtml(pStr(x['role']))}</div><div class="card-subtitle">${escapeHtml(pStr(x['company']))} | ${escapeHtml(pStr(x['start_date']))} - ${escapeHtml(pStr(x['end_date'], 'Present'))}</div><div style="margin-top:8px;font-size:12px;">${escapeHtml(pStr(x['description']))}</div></div>';
      }).join('')}
      ${projects.isNotEmpty ? '<div class="section-title">Projects</div>' : ''}
      ${projects.map((p) {
        final x = pMap(p);
        return '<div class="card-item"><div class="card-title">${escapeHtml(pStr(x['title']))}</div><div style="font-size:12px;margin-top:4px;">${escapeHtml(pStr(x['description']))}</div></div>';
      }).join('')}
    </div>
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
    final summary = pStr(data['professional_summary']);
    final exp = pList(data['experience']);
    final edu = pList(data['education']);
    final skills = pSkills(data['skills']);
    final certs = pList(data['certifications']);
    final projects = pList(data['projects']);
    final designation = pDesignation(data);
    final photoUrl = pProfilePhotoUrl(data);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: Container(
            color: Colors.white,
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_violet, _pink],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (photoUrl != null) ...[
                        pProfilePhoto(
                          url: photoUrl,
                          size: 90,
                          borderColor: Colors.white,
                          borderWidth: 3,
                        ),
                        const SizedBox(height: 12),
                      ] else ...[
                        pInitialsAvatar(
                          name: name,
                          size: 90,
                          bgColor: const Color(0xFF7C3AED),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text(name,
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                      if (designation.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(designation,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white70)),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 16,
                        runSpacing: 6,
                        children: [
                          if (email.isNotEmpty)
                            Text("📧 $email",
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.white)),
                          if (phone.isNotEmpty)
                            Text("📞 $phone",
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.white)),
                          if (location.isNotEmpty)
                            Text("📍 $location",
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.white)),
                        ],
                      ),
                    ],
                  ),
                ),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: constraints.maxWidth * 0.32,
                        color: _light,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sideTitle("SKILLS"),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: skills
                                  .map((s) => Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEDE9FE),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(s,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: _violet)),
                                      ))
                                  .toList(),
                            ),
                            const SizedBox(height: 20),
                            if (edu.isNotEmpty) ...[
                              _sideTitle("EDUCATION"),
                              ...edu.map((e) => _eduCard(pMap(e))),
                            ],
                            if (certs.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              _sideTitle("CERTIFICATIONS"),
                              ...certs.map((c) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text("▸ ",
                                            style: TextStyle(
                                                color: _pink,
                                                fontWeight: FontWeight.bold)),
                                        Expanded(
                                          child: Text(pCert(pMap(c)),
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.black87)),
                                        ),
                                      ],
                                    ),
                                  )),
                            ],
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (summary.isNotEmpty) ...[
                                _mainTitle("ABOUT ME"),
                                pInfoBox(summary,
                                    bg: Colors.white,
                                    leftBorder: _pink,
                                    textStyle: const TextStyle(
                                        fontSize: 13, height: 1.6)),
                                const SizedBox(height: 20),
                              ],
                              if (exp.isNotEmpty) ...[
                                _mainTitle("EXPERIENCE"),
                                ...exp.map((e) => _expCard(pMap(e))),
                                const SizedBox(height: 20),
                              ],
                              if (projects.isNotEmpty) ...[
                                _mainTitle("PROJECTS"),
                                ...projects.map((p) => _projCard(pMap(p))),
                              ],
                            ],
                          ),
                        ),
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

  Widget _sideTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _violet,
                    letterSpacing: 1.5)),
            const SizedBox(height: 4),
            Container(height: 2, width: 35, color: _pink),
          ],
        ),
      );

  Widget _mainTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _violet,
                    letterSpacing: 1.5)),
            const SizedBox(height: 4),
            Container(height: 2, width: 40, color: _pink),
          ],
        ),
      );

  Widget _eduCard(Map<String, dynamic> edu) => Container(
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: const Border(left: BorderSide(color: _violet, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pEduTitle(edu),
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _dark)),
            const SizedBox(height: 2),
            if (pEduSubtitle(edu).isNotEmpty)
              Text(pEduSubtitle(edu),
                  style:
                      const TextStyle(fontSize: 10, color: Colors.black54)),
          ],
        ),
      );

  Widget _expCard(Map<String, dynamic> exp) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: const Border(left: BorderSide(color: _violet, width: 4)),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pStr(exp['role'], 'Role'),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _dark)),
            const SizedBox(height: 2),
            Text(
                "${pStr(exp['company'])} | ${pStr(exp['start_date'])} - ${pStr(exp['end_date'], 'Present')}",
                style: const TextStyle(fontSize: 11, color: Colors.black54)),
            if (pStr(exp['description']).isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(pStr(exp['description']),
                  style: const TextStyle(fontSize: 11, height: 1.5)),
            ],
          ],
        ),
      );

  Widget _projCard(Map<String, dynamic> p) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: const Border(left: BorderSide(color: _pink, width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pStr(p['title'], 'Project'),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _dark)),
            if (pStr(p['description']).isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(pStr(p['description']),
                  style: const TextStyle(fontSize: 11, height: 1.4)),
            ],
          ],
        ),
      );

  @override
  pw.Widget buildPdfContent(
    Map<String, dynamic> data,
    PdfPageFormat pageFormat,
  ) {
    final violet = pdfColor(color);
    final pink = pdfColor('#EC4899');
    final violetLight =
        PdfColor(violet.red, violet.green, violet.blue, 0.12);

    final u = pdfMap(data['user_info']);
    final c = pdfMap(data['contact_info']);
    final name = pdfStr(u['full_name'], 'Your Name');
    final desig = pdfDesignation(data);
    final email = pdfStr(c['email']);
    final phone = pdfStr(c['phone']);
    final location = pdfLocation(data);
    final summary = pdfStr(data['professional_summary']);
    final edu = pdfList(data['education']);
    final exp = pdfList(data['experience']);
    final skills = pdfSkills(data['skills']);
    final certs = pdfList(data['certifications']);
    final projects = pdfList(data['projects']);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(24),
          decoration: pw.BoxDecoration(
            gradient: pw.LinearGradient(
              colors: [violet, pink],
              begin: pw.Alignment.topLeft,
              end: pw.Alignment.bottomRight,
            ),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pdfProfilePhoto(
                data: data,
                size: 84,
                borderColor: PdfColors.white,
                borderWidth: 2.5,
              ),
              pw.SizedBox(height: 10),
              pw.Text(pdfSafe(name),
                  style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white)),
              if (desig.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Text(pdfSafe(desig),
                    style: const pw.TextStyle(
                        fontSize: 11, color: PdfColors.white)),
              ],
              pw.SizedBox(height: 10),
              pw.Text(
                pdfSafe(
                  [email, phone, location]
                      .where((x) => x.isNotEmpty)
                      .join('  |  '),
                ),
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.white),
              ),
            ],
          ),
        ),
        pw.Expanded(
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                width: 175,
                color: PdfColors.grey100,
                padding: const pw.EdgeInsets.all(16),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (skills.isNotEmpty) ...[
                      pdfSideTitleColored('SKILLS', violet),
                      pw.Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: skills
                            .take(15)
                            .map((s) => pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: pw.BoxDecoration(
                                    color: violetLight,
                                    borderRadius: pw.BorderRadius.circular(8),
                                  ),
                                  child: pw.Text(pdfSafe(s),
                                      style: const pw.TextStyle(fontSize: 8)),
                                ))
                            .toList(),
                      ),
                      pw.SizedBox(height: 14),
                    ],
                    if (edu.isNotEmpty) ...[
                      pdfSideTitleColored('EDUCATION', violet),
                      ...edu.take(4).map((e) => pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 6),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  pdfSafe(pdfStr(e['degree'],
                                      pdfStr(e['level'], 'Education'))),
                                  style: pw.TextStyle(
                                      fontSize: 9,
                                      fontWeight: pw.FontWeight.bold),
                                ),
                                pw.Text(
                                  pdfSafe(
                                    [
                                      pdfStr(e['institute']),
                                      pdfStr(e['year_of_passing'],
                                          pdfStr(e['year'])),
                                    ].where((x) => x.isNotEmpty).join(' - '),
                                  ),
                                  style: const pw.TextStyle(fontSize: 8),
                                ),
                              ],
                            ),
                          )),
                    ],
                    if (certs.isNotEmpty) ...[
                      pw.SizedBox(height: 6),
                      pdfSideTitleColored('CERTIFICATIONS', pink),
                      ...certs.take(6).map((crt) => pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 3),
                            child: pw.Text('> ${pdfSafe(pdfStr(crt["name"]))}',
                                style: const pw.TextStyle(fontSize: 8)),
                          )),
                    ],
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(20),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (summary.isNotEmpty) ...[
                        pdfMainTitle('ABOUT ME', violet),
                        pw.Container(
                          width: double.infinity,
                          padding: const pw.EdgeInsets.all(10),
                          decoration: pw.BoxDecoration(
                            border: pw.Border(
                                left: pw.BorderSide(color: pink, width: 3)),
                          ),
                          child: pw.Text(pdfSafe(summary),
                              style: const pw.TextStyle(
                                  fontSize: 10, lineSpacing: 2)),
                        ),
                        pw.SizedBox(height: 14),
                      ],
                      if (exp.isNotEmpty) ...[
                        pdfMainTitle('EXPERIENCE', violet),
                        ...exp.map((e) => pdfExpBlockClassic(e, violet)),
                        pw.SizedBox(height: 12),
                      ],
                      if (projects.isNotEmpty) ...[
                        pdfMainTitle('PROJECTS', violet),
                        ...projects.map((p) => pdfProjBlockClassic(p, pink)),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}