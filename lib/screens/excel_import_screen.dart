import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';

class GlobalArchive {
  static List<List<dynamic>> rows = [];
}

class ExcelImportScreen extends StatefulWidget {
  const ExcelImportScreen({super.key});

  @override
  State<ExcelImportScreen> createState() => _ExcelImportScreenState();
}

class _ExcelImportScreenState extends State<ExcelImportScreen> {
  bool _isLoading = false;
  String _statusMessage = 'اختر ملف (CSV) للبدء في رفع البيانات';

  Future<void> _pickAndProcessFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result != null) {
        setState(() {
          _isLoading = true;
          _statusMessage = 'جاري تحليل الملف وقراءة الأعمدة...';
        });

        var bytes = result.files.single.bytes;
        if (bytes == null && result.files.single.path != null) {
          bytes = File(result.files.single.path!).readAsBytesSync();
        }

        if (bytes != null) {
          try {
            String csvString = utf8.decode(bytes, allowMalformed: true);
            List<String> lines = csvString.split(RegExp(r'\r\n|\n|\r'));

            List<List<dynamic>> parsedRows = [];
            int tripsCount = 0;
            int paymentsCount = 0;

            for (int i = 0; i < lines.length; i++) {
              String line = lines[i].trim();
              if (line.isEmpty) continue;

              String separator = line.contains(';') ? ';' : ',';
              List<String> row = line.split(separator);
              parsedRows.add(row);

              if (i > 0) {
                if (row.length > 1 && row[0].trim().isNotEmpty && row[0].trim() != '----------') {
                  tripsCount++;
                }
                if (row.length > 9) {
                  double payVal = double.tryParse(row[9].replaceAll('"', '').trim()) ?? 0;
                  if (payVal > 0) paymentsCount++;
                }
              }
            }

            GlobalArchive.rows = parsedRows;

            setState(() {
              _isLoading = false;
              _statusMessage = 'تم الاستيراد بنجاح!\nنقلات: $tripsCount | دفعات: $paymentsCount';
            });

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم استيراد الداتا وتحليل الأعمدة بنجاح', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  backgroundColor: Color(0xFF28A745),
                  behavior: SnackBarBehavior.floating,
                ),
              );

              await Future.delayed(const Duration(milliseconds: 1000));
              if (mounted) {
                Navigator.pop(context);
              }
            }
          } catch (decodeError) {
            setState(() {
              _isLoading = false;
              _statusMessage = 'خطأ في قراءة البيانات:\n$decodeError';
            });
          }
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'إيرور النظام الخارجي:\n$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F2A52), Color(0xFF1E4885)],
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
              ),
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'استيراد أرشيف العملاء',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Cairo'),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF4A78B9), width: 2),
                  ),
                  child: const Icon(Icons.description_rounded, size: 60, color: Color(0xFF0F2A52)),
                ),
                const SizedBox(height: 24),
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F2A52)),
                ),
                const SizedBox(height: 30),
                _isLoading
                    ? const CircularProgressIndicator(color: Color(0xFF28A745))
                    : ElevatedButton.icon(
                  onPressed: _pickAndProcessFile,
                  icon: const Icon(Icons.upload_file, size: 24, color: Colors.white),
                  label: const Text('اختيار ملف CSV', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF28A745),
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}