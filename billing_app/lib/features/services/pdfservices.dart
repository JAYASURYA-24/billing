import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import '../models/bill.dart';

Future<void> generateAndOpenPdf(Bill bill) async {
  final pdf = pw.Document();
  final grandTotal = bill.items.fold<double>(
    0.0,
    (sum, item) => sum + item.total,
  );
  final currentBilltotal = grandTotal;
  final totalPayable = bill.total;

  // Load custom font
  final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
  final ttf = pw.Font.ttf(fontData.buffer.asByteData());

  final dateStr = DateFormat('dd MMM yyyy').format(bill.createdAt.toDate());

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    'SASTHA INTERNATIONAL TRADINGS(SG) PTE. LTD.',
                    style: pw.TextStyle(
                      font: ttf,
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    '634 VEERASAMY ROAD',
                    style: pw.TextStyle(
                      font: ttf,
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '#01-140 SINGAPORE(200634)',
                    style: pw.TextStyle(
                      font: ttf,
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Email: sasthasga@gmail.com    ph.no: +6580134772',
                    style: pw.TextStyle(font: ttf),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Info Row
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Text('Reg No : ', style: pw.TextStyle(font: ttf)),
                        pw.Text('202442413M', style: pw.TextStyle(font: ttf)),
                      ],
                    ),

                    pw.Text('Invoice No :', style: pw.TextStyle(font: ttf)),
                    pw.Text(
                      '#${bill.billNumber}',
                      style: pw.TextStyle(
                        font: ttf,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text('Date Issued:', style: pw.TextStyle(font: ttf)),
                    pw.Text(dateStr, style: pw.TextStyle(font: ttf)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Issued to:', style: pw.TextStyle(font: ttf)),
                    pw.Text(
                      bill.shopName,
                      style: pw.TextStyle(
                        font: ttf,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // Table
            pw.Table.fromTextArray(
              border: pw.TableBorder.all(width: 1),
              cellAlignment: pw.Alignment.center,
              headerStyle: pw.TextStyle(
                font: ttf,
                fontWeight: pw.FontWeight.bold,
              ),
              // headerDecoration: const pw.BoxDecoration(
              //   color: PdfColor.fromInt(0xFFE0DAD3),
              // ),
              cellHeight: 30,
              columnWidths: {
                0: const pw.FixedColumnWidth(30),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FixedColumnWidth(40),
                3: const pw.FixedColumnWidth(70),
                4: const pw.FixedColumnWidth(80),
              },
              headers: ['NO', 'ITEM', 'QTY', 'PRICE \$', 'SUBTOTAL \$'],
              data: List<List<String>>.generate(bill.items.length, (index) {
                final item = bill.items[index];
                return [
                  '${index + 1}',
                  item.name,
                  ' ${item.quantity}',
                  ' ${item.price.toStringAsFixed(2)}',
                  ' ${item.total.toStringAsFixed(2)}',
                ];
              }),
              cellStyle: pw.TextStyle(font: ttf),
            ),
            pw.SizedBox(height: 6),
            // Grand Total
            pw.Container(
              // color: PdfColor.fromInt(0xFFBDBDBD),
              padding: const pw.EdgeInsets.symmetric(
                vertical: 6,
                horizontal: 12,
              ),
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'GRAND TOTAL :   \$ ${currentBilltotal.toStringAsFixed(2)}',
                style: pw.TextStyle(
                  font: ttf,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),

            pw.Container(
              // color: PdfColor.fromInt(0xFFBDBDBD),
              padding: const pw.EdgeInsets.symmetric(
                vertical: 3,
                horizontal: 12,
              ),
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'TOTAL PAYABLE :   \$ ${totalPayable.toStringAsFixed(2)}',
                style: pw.TextStyle(
                  font: ttf,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),

            // pw.SizedBox(height: 25),

            // Payment Info
            // pw.Text(
            //   'Payment Information',
            //   style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold),
            // ),
            // pw.SizedBox(height: 4),
            // pw.Text(
            //   'Paid Amount : \$ ${bill.paidAmount.toStringAsFixed(2)}',
            //   style: pw.TextStyle(font: ttf),
            // ),
            // pw.Text(
            //   'Balance     : \$ ${bill.remainingUnpaid.toStringAsFixed(2)}',
            //   style: pw.TextStyle(font: ttf),
            // ),
            pw.SizedBox(height: 30),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Payment Status : ${bill.isPaid ? 'Paid' : 'Unpaid'}',
                  style: pw.TextStyle(font: ttf),
                ),
                pw.Text(
                  'For Sastha International Tradings(sg)pte.ltd.,',
                  style: pw.TextStyle(font: ttf),
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            // Signatures
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  children: [
                    pw.Text(
                      '__________________',
                      style: pw.TextStyle(font: ttf),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text('Customer\'s Sign', style: pw.TextStyle(font: ttf)),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Text(
                      '________________________',
                      style: pw.TextStyle(font: ttf),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'DBS BANK,A/C NO : 0721264374',
                      style: pw.TextStyle(font: ttf),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [pw.Text("We appreciate your business!")],
            ),
          ],
        );
      },
    ),
  );

  final bytes = await pdf.save();
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/${bill.billNumber}_invoice.pdf');
  await file.writeAsBytes(bytes);
  await OpenFile.open(file.path);
}
