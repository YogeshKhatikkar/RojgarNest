// lib/features/resume/presentation/screens/format/formats/executive_format.dart
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../resume_format_base.dart';

class ExecutiveFormat extends ResumeFormatBase {
  @override
  String get id => 'executive';
  @override
  String get name => 'Executive Leadership';
  @override
  String get icon => '👔';
  @override
  String get description => 'Premium Professional Format';
  @override
  String get color => '#BF360C';
  @override
  String get styleKey => 'executive';
  @override
  String get templateType => 'executive';
  @override
  String get badgeText => 'Premium';

  static const Color _dark = Color(0xFF2C1810);
  static const Color _dark2 = Color(0xFF4A2818);
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _cream = Color(0xFFFFF9EF);

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
    final designation = pDesignation(resumeData);
    final photoUrl = pProfilePhotoUrl(resumeData);

    final desigHtml = designation.isNotEmpty
        ? '<div style="font-size:13px;color:#D4AF37;">${escapeHtml(designation)}</div>'
        : '';

    final photoHtml = photoUrl != null
        ? '<img src="${escapeHtml(photoUrl)}" style="width:100px;height:100px;border-radius:50%;object-fit:cover;border:3px solid #D4AF37;margin-bottom:12px;display:block;margin-left:auto;margin-right:auto;" onerror="this.style.display=\'none\'" />'
        : '';

    return '''
<!DOCTYPE html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:'Playfair Display',Georgia,serif;background:#fdfbf7;padding:30px 20px;line-height:1.6}
.resume-container{max-width:1000px;margin:0 auto;background:#fff;border:1px solid #d4af37;border-radius:8px;overflow:hidden;display:flex}
.sidebar{width:30%;background:#2C1810;color:#fff;padding:30px 20px}
.main{width:70%;padding:30px 35px}
.header{text-align:center;margin-bottom:20px;border-bottom:2px solid #d4af37;padding-bottom:15px}
.name{font-size:28px;font-weight:bold;color:#D4AF37}
.section-title{font-size:16px;font-weight:bold;color:#D4AF37;border-bottom:2px solid #d4af37;padding-bottom:5px;margin:20px 0 10px 0;text-transform:uppercase}
.sidebar .item{font-size:13px;color:#E2E8F0;margin-bottom:6px;padding-left:10px;position:relative}
.main .section-title{font-size:18px;font-weight:bold;color:#2C1810;border-bottom:2px solid #d4af37;padding-bottom:10px;margin-bottom:20px;text-transform:uppercase}
.card-item{padding:15px;margin-bottom:12px;background:#FFF9EF;border-left:4px solid #D4AF37;border-radius:4px}
.card-title{font-size:16px;font-weight:bold;color:#2C1810}
.card-subtitle{font-size:13px;color:#666;font-style:italic}
.summary-text{font-size:14px;line-height:1.7;padding:18px;background:#FFF9EF;border-left:4px solid #D4AF37;font-style:italic}
</style></head><body>
<div class="resume-container">
  <div class="sidebar">
    <div class="header">
      $photoHtml
      <div class="name">${escapeHtml(name)}</div>
      $desigHtml
      ${email.isNotEmpty ? '<div style="font-size:12px;color:#E2E8F0;margin-top:10px;">📧 ${escapeHtml(email)}</div>' : ''}
      ${phone.isNotEmpty ? '<div style="font-size:12px;color:#E2E8F0;">📞 ${escapeHtml(phone)}</div>' : ''}
      ${location.isNotEmpty ? '<div style="font-size:12px;color:#E2E8F0;">📍 ${escapeHtml(location)}</div>' : ''}
    </div>
    <div class="section-title">Core Competencies</div>
    ${skills.map((s) => '<div class="item">${escapeHtml(s)}</div>').join('')}
    <div class="section-title">Education</div>
    ${education.map((e) {
      final x = pMap(e);
      final title = pEduTitle(x);
      return '<div class="item"><strong>${escapeHtml(title)}</strong><br>${escapeHtml(pEduSubtitle(x))}</div>';
    }).join('')}
  </div>
  <div class="main">
    <div class="section-title">Executive Profile</div>
    <div class="summary-text">${escapeHtml(summary)}</div>
    <div class="section-title" style="margin-top:25px;">Professional Experience</div>
    ${experience.map((e) {
      final x = pMap(e);
      return '<div class="card-item"><div class="card-title">${escapeHtml(pStr(x['role']))}</div><div class="card-subtitle">${escapeHtml(pStr(x['company']))} | ${escapeHtml(pStr(x['start_date']))} - ${escapeHtml(pStr(x['end_date'], 'Present'))}</div><div style="margin-top:8px;font-size:13px;">${escapeHtml(pStr(x['description']))}</div></div>';
    }).join('')}
    <div class="section-title" style="margin-top:25px;">Certifications</div>
    ${certifications.map((c) => '<div class="item" style="color:#2C1810;font-size:13px;">• ${escapeHtml(pCert(pMap(c)))}</div>').join('')}
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
    final designation = pDesignation(data);
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
                    color: _dark,
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
                                  size: 85,
                                  borderColor: _gold,
                                  borderWidth: 2.5,
                                ),
                              ] else ...[
                                pInitialsAvatar(
                                  name: name,
                                  size: 85,
                                  bgColor: _dark,
                                  textColor: _gold,
                                ),
                              ],
                              const SizedBox(height: 10),
                              Text(name,
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: _gold),
                                  textAlign: TextAlign.center),
                              if (designation.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(designation,
                                    style: const TextStyle(
                                        fontSize: 11, color: _gold)),
                              ],
                              const SizedBox(height: 10),
                              if (email.isNotEmpty)
                                Text("📧 $email",
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFFE2E8F0))),
                              if (phone.isNotEmpty)
                                Text("📞 $phone",
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFFE2E8F0))),
                              if (location.isNotEmpty)
                                Text("📍 $location",
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFFE2E8F0))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (skills.isNotEmpty) ...[
                          _sidebarTitle("CORE COMPETENCIES"),
                          ...skills.map((s) => _sidebarItem(s)),
                          const SizedBox(height: 16),
                        ],
                        if (edu.isNotEmpty) ...[
                          _sidebarTitle("EDUCATION"),
                          ...edu.map((e) => _sidebarEduCard(pMap(e))),
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
                            _mainTitle("EXECUTIVE PROFILE"),
                            pInfoBox(summary,
                                bg: _cream,
                                leftBorder: _gold,
                                textStyle: const TextStyle(
                                    fontSize: 13,
                                    height: 1.6,
                                    fontStyle: FontStyle.italic,
                                    color: _dark)),
                            const SizedBox(height: 20),
                          ],
                          if (exp.isNotEmpty) ...[
                            _mainTitle("PROFESSIONAL EXPERIENCE"),
                            ...exp.map((e) => _expCard(pMap(e))),
                            const SizedBox(height: 20),
                          ],
                          if (certs.isNotEmpty) ...[
                            _mainTitle("CERTIFICATIONS"),
                            ...certs.map((c) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text("• ${pCert(pMap(c))}",
                                      style: const TextStyle(
                                          fontSize: 13, color: _dark)),
                                )),
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
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _gold,
                letterSpacing: 1)),
      );

  Widget _sidebarItem(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text("• $text",
            style: const TextStyle(fontSize: 12, color: Color(0xFFE2E8F0))),
      );

  Widget _sidebarEduCard(Map<String, dynamic> edu) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pEduTitle(edu),
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            if (pEduSubtitle(edu).isNotEmpty)
              Text(pEduSubtitle(edu),
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFFE2E8F0))),
          ],
        ),
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
                    color: _dark,
                    letterSpacing: 1)),
            const SizedBox(height: 4),
            Container(height: 2, width: 50, color: _gold),
          ],
        ),
      );

  Widget _expCard(Map<String, dynamic> exp) => pCard(
        bg: _cream,
        leftBorder: _gold,
        radius: 4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pStr(exp['role'], 'Role'),
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _dark)),
            const SizedBox(height: 2),
            Text(
                "${pStr(exp['company'])} | ${pStr(exp['start_date'])} - ${pStr(exp['end_date'], 'Present')}",
                style: const TextStyle(
                    fontSize: 12,
                    color: _dark2,
                    fontStyle: FontStyle.italic)),
            if (pStr(exp['description']).isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(pStr(exp['description']),
                  style: const TextStyle(
                      fontSize: 12, height: 1.5, color: _dark)),
            ],
          ],
        ),
      );

  @override
  pw.Widget buildPdfContent(
    Map<String, dynamic> data,
    PdfPageFormat pageFormat,
  ) {
    final dark = pdfColor('#2C1810');
    final gold = pdfColor(color.isEmpty ? '#D4AF37' : color);
    final cream = pdfColor('#FFF9EF');

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

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          width: 175,
          color: dark,
          padding: const pw.EdgeInsets.all(18),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 12),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                      bottom: pw.BorderSide(color: gold, width: 1.5)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pdfProfilePhoto(
                      data: data,
                      size: 80,
                      borderColor: gold,
                      borderWidth: 2,
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(pdfSafe(name),
                        style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: gold)),
                    if (desig.isNotEmpty)
                      pw.Text(pdfSafe(desig),
                          style: pw.TextStyle(fontSize: 9, color: gold)),
                    pw.SizedBox(height: 8),
                    if (email.isNotEmpty)
                      pw.Text(pdfSafe(email),
                          style: const pw.TextStyle(
                              fontSize: 8, color: PdfColors.grey300)),
                    if (phone.isNotEmpty)
                      pw.Text(pdfSafe(phone),
                          style: const pw.TextStyle(
                              fontSize: 8, color: PdfColors.grey300)),
                    if (location.isNotEmpty)
                      pw.Text(pdfSafe(location),
                          style: const pw.TextStyle(
                              fontSize: 8, color: PdfColors.grey300)),
                  ],
                ),
              ),
              if (skills.isNotEmpty) ...[
                pw.SizedBox(height: 14),
                pdfSideTitle('CORE COMPETENCIES', gold),
                ...skills
                    .take(15)
                    .map((s) => pdfSideItem('- ${pdfSafe(s)}', PdfColors.grey300)),
              ],
              if (edu.isNotEmpty) ...[
                pw.SizedBox(height: 14),
                pdfSideTitle('EDUCATION', gold),
                ...edu.take(3).map((e) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 6),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            pdfSafe(pdfStr(e['degree'],
                                pdfStr(e['level'], 'Degree'))),
                            style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white),
                          ),
                          pw.Text(pdfSafe(pdfStr(e['institute'])),
                              style: const pw.TextStyle(
                                  fontSize: 8, color: PdfColors.grey300)),
                        ],
                      ),
                    )),
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
                  pdfMainTitle('EXECUTIVE PROFILE', dark),
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: cream,
                      border: pw.Border(
                          left: pw.BorderSide(color: gold, width: 3)),
                    ),
                    child: pw.Text(pdfSafe(summary),
                        style: pw.TextStyle(
                            fontSize: 10,
                            lineSpacing: 2,
                            color: dark,
                            fontStyle: pw.FontStyle.italic)),
                  ),
                  pw.SizedBox(height: 16),
                ],
                if (exp.isNotEmpty) ...[
                  pdfMainTitle('PROFESSIONAL EXPERIENCE', dark),
                  ...exp.map((e) => pdfExpBlockExecutive(e, gold, cream, dark)),
                  pw.SizedBox(height: 12),
                ],
                if (certs.isNotEmpty) ...[
                  pdfMainTitle('CERTIFICATIONS', dark),
                  ...certs.take(8).map((crt) => pw.Text(
                      '- ${pdfSafe(pdfStr(crt["name"]))}',
                      style: pw.TextStyle(fontSize: 9, color: dark))),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}