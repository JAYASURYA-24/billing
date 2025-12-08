import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

import '../models/bill.dart';

Future<void> generateAndOpenPdf(
  Bill bill,
  bool showTallied, {
  Uint8List? signBytes,
}) async {
  final pdf = pw.Document();

  Uint8List? signatureBytes = signBytes;

  // Download signature from Firebase Storage if available
  if (signatureBytes == null && bill.signatureUrl != null) {
    try {
      final storage = FirebaseStorage.instance;
      final ref = storage.refFromURL(bill.signatureUrl!);
      signatureBytes = await ref.getData();
    } catch (e) {
      print("Signature download failed: $e");
    }
  }
  final grandTotal = bill.items.fold<double>(
    0.0,
    (sum, item) => sum + item.total,
  );

  double displayBalance;
  double discountedTotal = bill.discountedTotal;
  double discountAmount = bill.discountAmount;

  if (bill.previousUnpaid != 0.0) {
    displayBalance =
        bill.discountedTotal + bill.previousUnpaid - bill.paidAmount.abs();
  } else if (!bill.isPaid) {
    displayBalance = bill.discountedTotal - bill.paidAmount.abs();
  } else {
    displayBalance = 0.0;
  }

  final font = pw.Font.helvetica();
  final boldFont = pw.Font.helveticaBold();

  final dateStr = DateFormat('dd/MM/yy').format(bill.createdAt.toDate());
  final timeStr = DateFormat('HH:mm').format(bill.createdAt.toDate());

  pdf.addPage(
    pw.Page(
      // pageFormat: PdfPageFormat.a4,
      // margin: const pw.EdgeInsets.all(32),
      pageFormat: PdfPageFormat(
        72 * PdfPageFormat.mm, // match printer's printable width
        double.infinity,
        marginAll: 2 * PdfPageFormat.mm, // minimal margins
      ),
      build: (pw.Context context) {
        return pw.Column(
          // crossAxisAlignment: pw.CrossAxisAlignment.start,
          crossAxisAlignment:
              pw
                  .CrossAxisAlignment
                  .stretch, // stretch full width// 👈 Left align
          children: [
            // ---------------- Header ----------------
            pw.Center(
              child: pw.Text(
                'SASTHA INTERNATIONAL',
                style: pw.TextStyle(font: boldFont, fontSize: 9),
              ),
            ),
            pw.Center(
              child: pw.Text(
                'TRADINGS(SG) PTE. LTD.',
                style: pw.TextStyle(font: boldFont, fontSize: 9),
              ),
            ),
            pw.Center(
              child: pw.Text(
                '634 VEERASAMY ROAD',
                style: pw.TextStyle(font: font, fontSize: 7),
              ),
            ),
            pw.Center(
              child: pw.Text(
                '#01-140 SINGAPORE(200634)',
                style: pw.TextStyle(font: font, fontSize: 7),
              ),
            ),
            pw.Center(
              child: pw.Text(
                'sasthasga@gmail.com',
                style: pw.TextStyle(font: font, fontSize: 7),
              ),
            ),
            pw.Center(
              child: pw.Text(
                'Ph: +6580134772',
                style: pw.TextStyle(font: font, fontSize: 7),
              ),
            ),

            // pw.SizedBox(height: 2),
            // pw.Text(
            //   '----------------------------------------',
            //   style: pw.TextStyle(font: font, fontSize: 7),
            //   textAlign: pw.TextAlign.center,
            // ),
            dottedLine(200),
            // ---------------- Bill Info ----------------
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Reg: 202442413M',
                  style: pw.TextStyle(font: font, fontSize: 7),
                ),
                pw.Text(
                  '$dateStr $timeStr',
                  style: pw.TextStyle(font: font, fontSize: 7),
                ),
              ],
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Invoice: #${bill.billNumber}',
                  style: pw.TextStyle(font: boldFont, fontSize: 7),
                ),
                pw.Text(
                  bill.isPaid ? 'PAID' : 'UNPAID',
                  style: pw.TextStyle(font: boldFont, fontSize: 7),
                ),
              ],
            ),
            pw.Text(
              'To: ${bill.shopName}',
              style: pw.TextStyle(font: boldFont, fontSize: 8),
              textAlign: pw.TextAlign.center,
            ),

            pw.SizedBox(height: 4),
            dottedLine(200),
            // pw.Text(
            //   '----------------------------------------',
            //   style: pw.TextStyle(font: font, fontSize: 7),
            //   textAlign: pw.TextAlign.center,
            // ),

            // ---------------- Items Header ----------------
            pw.Row(
              children: [
                pw.Expanded(
                  flex: 4,
                  child: pw.Text(
                    'ITEM',
                    style: pw.TextStyle(font: boldFont, fontSize: 7),
                  ),
                ),
                pw.Expanded(
                  flex: 1,
                  child: pw.Text(
                    'QTY',
                    style: pw.TextStyle(font: boldFont, fontSize: 7),
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    'PRICE',
                    style: pw.TextStyle(font: boldFont, fontSize: 7),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    'TOTAL',
                    style: pw.TextStyle(font: boldFont, fontSize: 7),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ],
            ),
            dottedLine(200),
            // pw.Text(
            //   '----------------------------------------',
            //   style: pw.TextStyle(font: font, fontSize: 7),
            //   textAlign: pw.TextAlign.center,
            // ),

            // ---------------- Items List ----------------
            ...bill.items.map((item) {
              return pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 4,
                    child: pw.Text(
                      item.name,
                      style: pw.TextStyle(font: font, fontSize: 7),
                    ),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text(
                      '${item.quantity}',
                      style: pw.TextStyle(font: font, fontSize: 7),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      '\$${item.price.toStringAsFixed(2)}',
                      style: pw.TextStyle(font: font, fontSize: 7),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      '\$${item.total.toStringAsFixed(2)}',
                      style: pw.TextStyle(font: font, fontSize: 7),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              );
            }).toList(),
            dottedLine(200),
            // pw.Text(
            //   '----------------------------------------',
            //   style: pw.TextStyle(font: font, fontSize: 7),
            //   textAlign: pw.TextAlign.center,
            // ),

            // ---------------- Totals ----------------
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'SUBTOTAL:',
                  style: pw.TextStyle(font: font, fontSize: 8),
                ),
                pw.Text(
                  '\$${grandTotal.toStringAsFixed(2)}',
                  style: pw.TextStyle(font: boldFont, fontSize: 8),
                ),
              ],
            ),
            if (discountAmount > 0)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'DISCOUNT:',
                    style: pw.TextStyle(font: font, fontSize: 8),
                  ),
                  pw.Text(
                    '-\$${discountAmount.toStringAsFixed(2)}',
                    style: pw.TextStyle(font: font, fontSize: 8),
                  ),
                ],
              ),
            dottedLine(200),

            // pw.Text(
            //   '----------------------------------------',
            //   style: pw.TextStyle(font: font, fontSize: 7),
            //   textAlign: pw.TextAlign.center,
            // ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'GRAND TOTAL:',
                  style: pw.TextStyle(font: boldFont, fontSize: 11),
                ),
                pw.Text(
                  '\$${discountedTotal.toStringAsFixed(2)}',
                  style: pw.TextStyle(font: boldFont, fontSize: 11),
                ),
              ],
            ),
            if (bill.paidAmount > 0)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'PAID:',
                    style: pw.TextStyle(font: font, fontSize: 8),
                  ),
                  pw.Text(
                    '\$${bill.paidAmount.toStringAsFixed(2)}',
                    style: pw.TextStyle(font: font, fontSize: 8),
                  ),
                ],
              ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'OUTSTANDING:',
                  style: pw.TextStyle(font: boldFont, fontSize: 8),
                ),
                pw.Text(
                  '\$${displayBalance.toStringAsFixed(2)}',
                  style: pw.TextStyle(font: boldFont, fontSize: 8),
                ),
              ],
            ),

            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(
                'We appreciate your business!',
                style: pw.TextStyle(font: font, fontSize: 7),
              ),
            ),

            pw.SizedBox(height: 6),

            // ---------------- Footer ----------------
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Customer sign
                pw.Column(
                  children: [
                    // if (signBytes != null)
                    //   pw.Image(
                    //     pw.MemoryImage(signBytes),
                    //     width: 100,
                    //     height: 30,
                    //   )
                    if (signatureBytes != null)
                      pw.Image(
                        pw.MemoryImage(signatureBytes),
                        width: 100,
                        height: 30,
                      )
                    else
                      pw.Container(
                        width: 80,
                        height: 30,
                        alignment: pw.Alignment.bottomCenter,
                        child: pw.Text(
                          '________________',
                          style: pw.TextStyle(font: font, fontSize: 7),
                        ),
                      ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Customer Sign',
                      style: pw.TextStyle(font: font, fontSize: 7),
                    ),
                  ],
                ),
                // Bank details
                pw.Column(
                  children: [
                    pw.Container(width: 100, height: 30),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'DBS BANK A/C: 0721264374',
                      style: pw.TextStyle(font: font, fontSize: 6),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 10),
          ],
        );
      },
    ),
  );

  final bytes = await pdf.save();
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/${bill.billNumber}_invoice.pdf');
  await file.writeAsBytes(bytes);
  await OpenFilex.open(file.path);
}

pw.Widget dottedLine(double width) {
  return pw.Padding(
    padding: pw.EdgeInsets.symmetric(vertical: 8),
    child: pw.LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 2.0;
        const dashSpace = 2.0;
        final dashCount = (width / (dashWidth + dashSpace)).floor();
        return pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: List.generate(dashCount, (_) {
            return pw.Container(
              width: dashWidth,
              height: 1,
              color: PdfColors.black,
            );
          }),
        );
      },
    ),
  );
}
