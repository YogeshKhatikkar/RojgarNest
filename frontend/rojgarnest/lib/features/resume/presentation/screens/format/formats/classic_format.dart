// lib/features/resume/presentation/screens/format/formats/classic_format.dart
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../resume_format_base.dart';

class ClassicFormat extends ResumeFormatBase {
  @override
  String get id => 'classic';
  @override
  String get name => 'Classic Professional';
  @override
  String get icon => '📄';
  @override
  String get description => 'Clean & Traditional Design';
  @override
  String get color => '#1E3A8A';
  @override
  String get styleKey => 'classic';
  @override
  String get templateType => 'classic';
  @override
  String get badgeText => 'Most Popular';

  static const Color _primary = Color(0xFF1E3A8A);
  static const Color _bg = Color(0xFFF8F8F8);
  static const Color _cardBg = Color(0xFFFAFAFA);
  static const Color _text = Color(0xFF111111);
  static const Color _muted = Color(0xFF555555);

  // ============================================================
  // 1️⃣ HTML
  // ============================================================
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
    final tools = pTools(resumeData, 12);
    final photoUrl = pProfilePhotoUrl(resumeData);

    final desigHtml = designation.isNotEmpty
        ? '<div style="font-size:12px;color:#93C5FD;">${escapeHtml(designation)}</div>'
        : '';

    final photoHtml = photoUrl != null
        ? '<img src="${escapeHtml(photoUrl)}" style="width:100px;height:100px;border-radius:50%;object-fit:cover;border:3px solid #fff;margin-bottom:12px;display:block;margin-left:auto;margin-right:auto;" onerror="this.style.display=\'none\'" />'
        : '';

    final toolsHtml = tools.isNotEmpty
        ? '<div class="section-title">Tools</div><div>${tools.map((t) => '<span class="skill-chip">${escapeHtml(t)}</span>').join(' ')}</div>'
        : '';

    return '''
<!DOCTYPE html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>$name</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:Georgia,serif;background:#f8f8f8;padding:30px 20px;line-height:1.6}
.resume-container{max-width:1000px;margin:0 auto;background:#fff;box-shadow:0 10px 40px rgba(0,0,0,.1);overflow:hidden;display:flex}
.sidebar{width:30%;background:#1E3A8A;color:#fff;padding:30px 20px}
.main{width:70%;padding:30px 35px}
.header{text-align:center;margin-bottom:20px}
.name{font-size:32px;font-weight:bold;color:#1E3A8A}
.sidebar .section-title{font-size:16px;font-weight:bold;color:#fff;border-bottom:2px solid #fff;padding-bottom:5px;margin:20px 0 10px 0;text-transform:uppercase}
.sidebar .skill-chip{display:inline-block;background:rgba(255,255,255,.15);padding:4px 10px;border-radius:15px;font-size:12px;margin:3px}
.sidebar .item{font-size:13px;color:#E2E8F0;margin-bottom:6px;padding-left:10px;position:relative}
.main .section-title{font-size:20px;font-weight:bold;color:#1E3A8A;border-bottom:2px solid #1E3A8A;padding-bottom:10px;margin-bottom:20px;text-transform:uppercase}
.card-item{padding:15px;margin-bottom:12px;background:#FAFAFA;border-radius:8px;border-left:4px solid #1E3A8A}
.card-title{font-size:16px;font-weight:bold;color:#111}
.card-subtitle{font-size:14px;color:#555}
.summary-text{font-size:14px;line-height:1.7;padding:15px;background:#F8F8F8;border-radius:8px}
</style></head><body>
<div class="resume-container">
  <div class="sidebar">
    <div style="text-align:center;margin-bottom:20px;">
      $photoHtml
      <div style="font-size:24px;font-weight:bold;">${escapeHtml(name)}</div>
      $desigHtml
    </div>
    <div class="section-title">Contact</div>
    <div class="item">📧 ${escapeHtml(email)}</div>
    <div class="item">📞 ${escapeHtml(phone)}</div>
    <div class="item">📍 ${escapeHtml(location)}</div>
    <div class="section-title">Skills</div>
    <div>${skills.map((s) => '<span class="skill-chip">${escapeHtml(s)}</span>').join(' ')}</div>
    $toolsHtml
    <div class="section-title">Certifications</div>
    ${certifications.map((c) => '<div class="item">${escapeHtml(pCert(pMap(c)))}</div>').join('')}
  </div>
  <div class="main">
    <div class="section-title">Professional Summary</div>
    <div class="summary-text">${escapeHtml(summary)}</div>

    <div class="section-title" style="margin-top:25px;">Work Experience</div>
    ${experience.map((e) {
      final x = pMap(e);
      return '<div class="card-item"><div class="card-title">${escapeHtml(pStr(x['role']))}</div><div class="card-subtitle">${escapeHtml(pStr(x['company']))} | ${escapeHtml(pStr(x['start_date']))} - ${escapeHtml(pStr(x['end_date'], 'Present'))}</div><div style="margin-top:8px;font-size:13px;">${escapeHtml(pStr(x['description']))}</div></div>';
    }).join('')}

    <div class="section-title" style="margin-top:25px;">Education</div>
    ${education.map((e) {
      final x = pMap(e);
      final title = pEduTitle(x);
      return '<div class="card-item"><div class="card-title">${escapeHtml(title)}</div><div class="card-subtitle">${escapeHtml(pEduSubtitle(x))}</div></div>';
    }).join('')}

    <div class="section-title" style="margin-top:25px;">Projects</div>
    ${projects.map((p) {
      final x = pMap(p);
      return '<div class="card-item"><div class="card-title">${escapeHtml(pStr(x['title']))}</div><div style="font-size:13px;margin-top:4px;">${escapeHtml(pStr(x['description']))}</div></div>';
    }).join('')}
  </div>
</div>
</body></html>''';
  }

  // ============================================================
  // 2️⃣ FLUTTER PREVIEW
  // ============================================================
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
    final tools = pTools(data, 12);
    final photoUrl = pProfilePhotoUrl(data);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: Container(
            color: Colors.white,
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: constraints.maxWidth * 0.30,
                    color: _primary,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Column(
                            children: [
                              if (photoUrl != null) ...[
                                pProfilePhoto(
                                  url: photoUrl,
                                  size: 82,
                                  borderColor: Colors.white,
                                  borderWidth: 2.5,
                                ),
                              ] else ...[
                                pInitialsAvatar(
                                  name: name,
                                  size: 82,
                                  bgColor: const Color(0xFF0F2557),
                                ),
                              ],
                              const SizedBox(height: 10),
                              Text(name,
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white),
                                  textAlign: TextAlign.center),
                              if (designation.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(designation,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF93C5FD))),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _sidebarTitle("CONTACT"),
                        if (email.isNotEmpty) _sidebarItem("📧 $email"),
                        if (phone.isNotEmpty) _sidebarItem("📞 $phone"),
                        if (location.isNotEmpty) _sidebarItem("📍 $location"),
                        if (skills.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _sidebarTitle("SKILLS"),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: skills.map((s) => _sidebarChip(s)).toList(),
                          ),
                        ],
                        if (tools.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _sidebarTitle("TOOLS"),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: tools.map((s) => _sidebarChip(s)).toList(),
                          ),
                        ],
                        if (certs.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _sidebarTitle("CERTIFICATIONS"),
                          ...certs.map((c) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text("• ${pCert(pMap(c))}",
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFFE2E8F0))),
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
                          _mainTitle("PROFESSIONAL SUMMARY"),
                          pInfoBox(summary, bg: _bg),
                          const SizedBox(height: 20),
                          if (exp.isNotEmpty) ...[
                            _mainTitle("WORK EXPERIENCE"),
                            ...exp.map((e) => _expCard(pMap(e))),
                            const SizedBox(height: 20),
                          ],
                          if (edu.isNotEmpty) ...[
                            _mainTitle("EDUCATION"),
                            ...edu.map((e) => _eduCard(pMap(e))),
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
          ),
        );
      },
    );
  }

  Widget _sidebarTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(title,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1)),
      );

  Widget _sidebarItem(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(fontSize: 12, color: Color(0xFFE2E8F0))),
      );

  Widget _sidebarChip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12)),
        child: Text(text,
            style: const TextStyle(fontSize: 11, color: Colors.white)),
      );

  Widget _mainTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _primary,
                    letterSpacing: 0.5)),
            const SizedBox(height: 4),
            Container(height: 2, width: 50, color: _primary),
          ],
        ),
      );

  Widget _expCard(Map<String, dynamic> exp) => pCard(
        bg: _cardBg,
        leftBorder: _primary,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pStr(exp['role'], 'Role'),
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold, color: _text)),
            const SizedBox(height: 2),
            Text(
                "${pStr(exp['company'])} | ${pStr(exp['start_date'])} - ${pStr(exp['end_date'], 'Present')}",
                style: const TextStyle(fontSize: 13, color: _muted)),
            if (pStr(exp['description']).isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(pStr(exp['description']),
                  style: const TextStyle(fontSize: 13, height: 1.4)),
            ],
          ],
        ),
      );

  Widget _eduCard(Map<String, dynamic> edu) => pCard(
        bg: _cardBg,
        leftBorder: _primary,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pEduTitle(edu),
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            if (pEduSubtitle(edu).isNotEmpty)
              Text(pEduSubtitle(edu),
                  style: const TextStyle(fontSize: 13, color: _muted)),
          ],
        ),
      );

  Widget _projCard(Map<String, dynamic> p) => pCard(
        bg: _cardBg,
        leftBorder: _primary,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pStr(p['title'], 'Project'),
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
            if (pStr(p['description']).isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(pStr(p['description']),
                  style: const TextStyle(fontSize: 13, height: 1.4)),
            ],
          ],
        ),
      );

  // ============================================================
  // 3️⃣ PDF CONTENT
  // ============================================================
  @override
  pw.Widget buildPdfContent(
    Map<String, dynamic> data,
    PdfPageFormat pageFormat,
  ) {
    final accent = pdfColor(color);
    final accentLight = PdfColor(accent.red, accent.green, accent.blue, 0.12);

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
    final tools = pdfTools(data);

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          width: 175,
          color: accent,
          padding: const pw.EdgeInsets.all(18),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pdfProfilePhoto(
                  data: data,
                  size: 78,
                  borderColor: PdfColors.white,
                  borderWidth: 2,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(pdfSafe(name),
                    style: pw.TextStyle(
                        fontSize: 15,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white)),
              ),
              if (desig.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(pdfSafe(desig),
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.white)),
                ),
              ],
              pw.SizedBox(height: 14),
              pdfSideTitle('CONTACT', PdfColors.white),
              if (email.isNotEmpty)
                pdfSideItem('E: ${pdfSafe(email)}', PdfColors.white),
              if (phone.isNotEmpty)
                pdfSideItem('P: ${pdfSafe(phone)}', PdfColors.white),
              if (location.isNotEmpty)
                pdfSideItem('L: ${pdfSafe(location)}', PdfColors.white),
              if (skills.isNotEmpty) ...[
                pw.SizedBox(height: 12),
                pdfSideTitle('SKILLS', PdfColors.white),
                ...skills
                    .take(15)
                    .map((s) => pdfSideItem('- ${pdfSafe(s)}', PdfColors.white)),
              ],
              if (tools.isNotEmpty) ...[
                pw.SizedBox(height: 12),
                pdfSideTitle('TOOLS', PdfColors.white),
                ...tools
                    .take(10)
                    .map((s) => pdfSideItem('- ${pdfSafe(s)}', PdfColors.white)),
              ],
              if (certs.isNotEmpty) ...[
                pw.SizedBox(height: 12),
                pdfSideTitle('CERTIFICATIONS', PdfColors.white),
                ...certs.take(8).map((cert) {
                  final line = [
                    pdfStr(cert['name']),
                    pdfStr(cert['issuer']),
                  ].where((x) => x.isNotEmpty).join(' - ');
                  return pdfSideItem('- ${pdfSafe(line)}', PdfColors.white);
                }),
              ],
            ],
          ),
        ),
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(22),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (summary.isNotEmpty) ...[
                  pdfMainTitle('PROFESSIONAL SUMMARY', accent),
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: accentLight,
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Text(pdfSafe(summary),
                        style:
                            const pw.TextStyle(fontSize: 10, lineSpacing: 2)),
                  ),
                  pw.SizedBox(height: 16),
                ],
                if (exp.isNotEmpty) ...[
                  pdfMainTitle('WORK EXPERIENCE', accent),
                  ...exp.map((e) => pdfExpBlockClassic(e, accent)),
                  pw.SizedBox(height: 12),
                ],
                if (edu.isNotEmpty) ...[
                  pdfMainTitle('EDUCATION', accent),
                  ...edu.map((e) => pdfEduBlockClassic(e, accent)),
                  pw.SizedBox(height: 12),
                ],
                if (projects.isNotEmpty) ...[
                  pdfMainTitle('PROJECTS', accent),
                  ...projects.map((p) => pdfProjBlockClassic(p, accent)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}