// lib/features/resume/presentation/screens/format/formats/tech_format.dart
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../resume_format_base.dart';

class TechFormat extends ResumeFormatBase {
  @override
  String get id => 'tech';
  @override
  String get name => 'Tech / IT Specialist';
  @override
  String get icon => '💻';
  @override
  String get description => 'Developer-Focused Design';
  @override
  String get color => '#0F172A';
  @override
  String get styleKey => 'tech';
  @override
  String get templateType => 'tech';
  @override
  String get badgeText => 'Developer';

  static const Color _navy = Color(0xFF0F172A);
  static const Color _card = Color(0xFF1E293B);
  static const Color _accent = Color(0xFF06B6D4);
  static const Color _green = Color(0xFF10B981);
  static const Color _grey = Color(0xFF94A3B8);

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
    final tools = pTools(resumeData, 15);
    final photoUrl = pProfilePhotoUrl(resumeData);

    final desigHtml = designation.isNotEmpty
        ? '<div style="font-size:13px;color:#06B6D4;">${escapeHtml(designation)}</div>'
        : '';

    final photoHtml = photoUrl != null
        ? '<img src="${escapeHtml(photoUrl)}" style="width:90px;height:90px;border-radius:50%;object-fit:cover;border:3px solid #06B6D4;margin-bottom:10px;" onerror="this.style.display=\'none\'" />'
        : '';

    return '''
<!DOCTYPE html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:'JetBrains Mono','Fira Code',Consolas,monospace;background:#0F172A;padding:30px 20px;line-height:1.6;color:#E2E8F0}
.resume-container{max-width:1000px;margin:0 auto;background:#1E293B;border-radius:16px;overflow:hidden;border:1px solid #334155;display:flex}
.sidebar{width:32%;background:#0F172A;padding:30px 22px;border-right:1px solid #334155}
.main{width:68%;padding:30px 32px}
.header{margin-bottom:24px;padding-bottom:20px;border-bottom:2px solid #06B6D4;text-align:center;}
.name{font-size:26px;font-weight:800;color:#06B6D4}
.section-title{font-size:12px;font-weight:700;color:#06B6D4;text-transform:uppercase;letter-spacing:1.5px;margin:20px 0 12px 0;padding-bottom:6px;border-bottom:1px dashed #334155}
.section-title:first-child{margin-top:0}
.skill-chip{display:inline-block;background:#0F172A;color:#06B6D4;padding:4px 10px;border-radius:6px;font-size:11px;font-weight:600;margin:3px;border:1px solid #06B6D4}
.card-item{padding:14px;margin-bottom:12px;background:#0F172A;border-radius:10px;border-left:3px solid #10B981}
.card-title{font-size:14px;font-weight:700;color:#F1F5F9}
.card-subtitle{font-size:11px;color:#94A3B8;margin-top:4px}
.summary-text{font-size:12px;line-height:1.7;padding:16px;background:#0F172A;border-radius:10px;border-left:3px solid #06B6D4;color:#CBD5E1}
.item{font-size:11px;color:#CBD5E1;margin-bottom:6px}
.item strong{color:#06B6D4}
</style></head><body>
<div class="resume-container">
  <div class="sidebar">
    <div class="header">
      $photoHtml
      <div class="name">${escapeHtml(name)}</div>
      $desigHtml
    </div>
    <div class="section-title">Contact</div>
    <div class="item">📧 ${escapeHtml(email)}</div>
    <div class="item">📞 ${escapeHtml(phone)}</div>
    <div class="item">📍 ${escapeHtml(location)}</div>
    <div class="section-title">Skills</div>
    <div>${skills.map((s) => '<span class="skill-chip">${escapeHtml(s)}</span>').join(' ')}</div>
    ${tools.isNotEmpty ? '<div class="section-title">Tools</div>' : ''}
    ${tools.isNotEmpty ? '<div>${tools.map((s) => '<span class="skill-chip">${escapeHtml(s)}</span>').join(' ')}</div>' : ''}
    ${education.isNotEmpty ? '<div class="section-title">Education</div>' : ''}
    ${education.map((e) {
      final x = pMap(e);
      return '<div class="item"><strong>${escapeHtml(pEduTitle(x))}</strong><br>${escapeHtml(pEduSubtitle(x))}</div>';
    }).join('')}
    ${certifications.isNotEmpty ? '<div class="section-title">Certifications</div>' : ''}
    ${certifications.map((c) => '<div class="item">▸ ${escapeHtml(pCert(pMap(c)))}</div>').join('')}
  </div>
  <div class="main">
    <div class="section-title">Summary</div>
    <div class="summary-text">${escapeHtml(summary)}</div>
    <div class="section-title" style="margin-top:24px;">Experience</div>
    ${experience.map((e) {
      final x = pMap(e);
      return '<div class="card-item"><div class="card-title">${escapeHtml(pStr(x['role']))}</div><div class="card-subtitle">${escapeHtml(pStr(x['company']))} | ${escapeHtml(pStr(x['start_date']))} - ${escapeHtml(pStr(x['end_date'], 'Present'))}</div><div style="margin-top:8px;font-size:12px;color:#CBD5E1;">${escapeHtml(pStr(x['description']))}</div></div>';
    }).join('')}
    <div class="section-title" style="margin-top:24px;">Projects</div>
    ${projects.map((p) {
      final x = pMap(p);
      return '<div class="card-item"><div class="card-title">${escapeHtml(pStr(x['title']))}</div><div style="font-size:12px;margin-top:6px;color:#CBD5E1;">${escapeHtml(pStr(x['description']))}</div></div>';
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
    final summary = pStr(data['professional_summary']);
    final exp = pList(data['experience']);
    final edu = pList(data['education']);
    final skills = pSkills(data['skills']);
    final certs = pList(data['certifications']);
    final projects = pList(data['projects']);
    final designation = pDesignation(data);
    final tools = pTools(data, 15);
    final photoUrl = pProfilePhotoUrl(data);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: Container(
            color: _navy,
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: constraints.maxWidth * 0.32,
                    color: _navy,
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.only(bottom: 18),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: const BoxDecoration(
                            border: Border(
                                bottom: BorderSide(color: _accent, width: 2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: photoUrl != null
                                    ? pProfilePhoto(
                                        url: photoUrl,
                                        size: 82,
                                        borderColor: _accent,
                                        borderWidth: 2.5,
                                      )
                                    : pInitialsAvatar(
                                        name: name,
                                        size: 82,
                                        bgColor: _navy,
                                      ),
                              ),
                              const SizedBox(height: 10),
                              Center(
                                child: Text(name,
                                    style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: _accent)),
                              ),
                              if (designation.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Center(
                                  child: Text(designation,
                                      style: const TextStyle(
                                          fontSize: 12, color: _accent)),
                                ),
                              ],
                            ],
                          ),
                        ),
                        _sideTitle("\$ CONTACT"),
                        _item("📧 $email"),
                        _item("📞 $phone"),
                        _item("📍 $location"),
                        if (skills.isNotEmpty) ...[
                          _sideTitle("\$ SKILLS"),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: skills
                                .map((s) => Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _navy,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: _accent, width: 1),
                                      ),
                                      child: Text(s,
                                          style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: _accent)),
                                    ))
                                .toList(),
                          ),
                        ],
                        if (tools.isNotEmpty) ...[
                          _sideTitle("\$ TOOLS"),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: tools
                                .map((s) => Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _navy,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: _accent, width: 1),
                                      ),
                                      child: Text(s,
                                          style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: _accent)),
                                    ))
                                .toList(),
                          ),
                        ],
                        if (edu.isNotEmpty) ...[
                          _sideTitle("\$ EDUCATION"),
                          ...edu.map((e) => _sidebarEdu(pMap(e))),
                        ],
                        if (certs.isNotEmpty) ...[
                          _sideTitle("\$ CERTIFICATIONS"),
                          ...certs.map((c) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text("▸ ${pCert(pMap(c))}",
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFFCBD5E1))),
                              )),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      color: _card,
                      padding: const EdgeInsets.all(26),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _mainTitle("\$ SUMMARY"),
                          pInfoBox(summary,
                              bg: _navy,
                              leftBorder: _accent,
                              textStyle: const TextStyle(
                                  fontSize: 12,
                                  height: 1.7,
                                  color: Color(0xFFCBD5E1))),
                          const SizedBox(height: 24),
                          if (exp.isNotEmpty) ...[
                            _mainTitle("\$ EXPERIENCE"),
                            ...exp.map((e) => _expCard(pMap(e))),
                            const SizedBox(height: 20),
                          ],
                          if (projects.isNotEmpty) ...[
                            _mainTitle("\$ PROJECTS"),
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

  Widget _sideTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 12),
        child: Text(t,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _accent,
                letterSpacing: 1.2)),
      );

  Widget _item(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t,
            style: const TextStyle(fontSize: 10, color: Color(0xFFCBD5E1))),
      );

  Widget _sidebarEdu(Map<String, dynamic> edu) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pEduTitle(edu),
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _accent)),
            if (pEduSubtitle(edu).isNotEmpty)
              Text(pEduSubtitle(edu),
                  style: const TextStyle(
                      fontSize: 10, color: Color(0xFF94A3B8))),
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
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _accent,
                    letterSpacing: 1.5)),
            const SizedBox(height: 6),
            Container(height: 1, color: const Color(0xFF334155)),
          ],
        ),
      );

  Widget _expCard(Map<String, dynamic> exp) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _navy,
          borderRadius: BorderRadius.circular(10),
          border: const Border(left: BorderSide(color: _green, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pStr(exp['role'], 'Role'),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF1F5F9))),
            const SizedBox(height: 4),
            Text(
                "${pStr(exp['company'])} | ${pStr(exp['start_date'])} - ${pStr(exp['end_date'], 'Present')}",
                style:
                    const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
            if (pStr(exp['description']).isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(pStr(exp['description']),
                  style: const TextStyle(
                      fontSize: 11,
                      height: 1.5,
                      color: Color(0xFFCBD5E1))),
            ],
          ],
        ),
      );

  Widget _projCard(Map<String, dynamic> p) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _navy,
          borderRadius: BorderRadius.circular(10),
          border: const Border(left: BorderSide(color: _accent, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pStr(p['title'], 'Project'),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF1F5F9))),
            if (pStr(p['description']).isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(pStr(p['description']),
                  style: const TextStyle(
                      fontSize: 11,
                      height: 1.5,
                      color: Color(0xFFCBD5E1))),
            ],
          ],
        ),
      );

  @override
  pw.Widget buildPdfContent(
    Map<String, dynamic> data,
    PdfPageFormat pageFormat,
  ) {
    final navy = pdfColor('#0F172A');
    final card = pdfColor('#1E293B');
    final accent = pdfColor(color.isEmpty ? '#06B6D4' : color);
    final green = pdfColor('#10B981');
    final grey = pdfColor('#94A3B8');

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

    return pw.Container(
      color: navy,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            width: 180,
            color: navy,
            padding: const pw.EdgeInsets.all(18),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.only(bottom: 12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border(
                        bottom: pw.BorderSide(color: accent, width: 1.5)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pdfProfilePhoto(
                        data: data,
                        size: 78,
                        borderColor: accent,
                        borderWidth: 2,
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(pdfSafe(name),
                          style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: accent)),
                      if (desig.isNotEmpty)
                        pw.Text(pdfSafe(desig),
                            style: pw.TextStyle(fontSize: 9, color: accent)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),
                pdfSideTitle('\$ CONTACT', accent),
                if (email.isNotEmpty) pdfSideItem(pdfSafe(email), grey),
                if (phone.isNotEmpty) pdfSideItem(pdfSafe(phone), grey),
                if (location.isNotEmpty) pdfSideItem(pdfSafe(location), grey),
                if (skills.isNotEmpty) ...[
                  pw.SizedBox(height: 12),
                  pdfSideTitle('\$ SKILLS', accent),
                  pw.Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: skills
                        .take(15)
                        .map((s) => pw.Container(
                              padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(color: accent, width: 0.5),
                                borderRadius: pw.BorderRadius.circular(4),
                              ),
                              child: pw.Text(pdfSafe(s),
                                  style: pw.TextStyle(
                                      fontSize: 8, color: accent)),
                            ))
                        .toList(),
                  ),
                ],
                if (tools.isNotEmpty) ...[
                  pw.SizedBox(height: 12),
                  pdfSideTitle('\$ TOOLS', accent),
                  pw.Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: tools
                        .take(10)
                        .map((s) => pw.Container(
                              padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(color: accent, width: 0.5),
                                borderRadius: pw.BorderRadius.circular(4),
                              ),
                              child: pw.Text(pdfSafe(s),
                                  style: pw.TextStyle(
                                      fontSize: 8, color: accent)),
                            ))
                        .toList(),
                  ),
                ],
                if (edu.isNotEmpty) ...[
                  pw.SizedBox(height: 12),
                  pdfSideTitle('\$ EDUCATION', accent),
                  ...edu.take(3).map((e) => pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 6),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              pdfSafe(pdfStr(
                                  e['degree'], pdfStr(e['level'], 'Education'))),
                              style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: accent),
                            ),
                            pw.Text(pdfSafe(pdfStr(e['institute'])),
                                style: pw.TextStyle(fontSize: 8, color: grey)),
                          ],
                        ),
                      )),
                ],
                if (certs.isNotEmpty) ...[
                  pw.SizedBox(height: 12),
                  pdfSideTitle('\$ CERTIFICATIONS', accent),
                  ...certs.take(5).map((crt) => pw.Text(
                      '> ${pdfSafe(pdfStr(crt["name"]))}',
                      style: pw.TextStyle(fontSize: 8, color: grey))),
                ],
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Container(
              color: card,
              padding: const pw.EdgeInsets.all(22),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (summary.isNotEmpty) ...[
                    pdfMainTitleTech('\$ SUMMARY', accent),
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: navy,
                        border: pw.Border(
                            left: pw.BorderSide(color: accent, width: 3)),
                      ),
                      child: pw.Text(pdfSafe(summary),
                          style: pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey300,
                              lineSpacing: 2)),
                    ),
                    pw.SizedBox(height: 14),
                  ],
                  if (exp.isNotEmpty) ...[
                    pdfMainTitleTech('\$ EXPERIENCE', accent),
                    ...exp.map((e) => pdfExpBlockTech(e, green, navy, grey)),
                    pw.SizedBox(height: 12),
                  ],
                  if (projects.isNotEmpty) ...[
                    pdfMainTitleTech('\$ PROJECTS', accent),
                    ...projects
                        .map((p) => pdfProjBlockTech(p, accent, navy, grey)),
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