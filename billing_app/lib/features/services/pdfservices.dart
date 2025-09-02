import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import '../models/bill.dart';

Future<void> generateAndOpenPdf(
  Bill bill,
  bool showTallied, {
  Uint8List? signBytes,
}) async {
  final pdf = pw.Document();
  final grandTotal = bill.items.fold<double>(
    0.0,
    (sum, item) => sum + item.total,
  );
  final currentBilltotal = grandTotal;

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

  // Use built-in Courier font (monospace - perfect for thermal printing)
  // final font = pw.Font.courier();
  // final boldFont = pw.Font.courierBold();
  final font = pw.Font.helvetica();
  final boldFont = pw.Font.helveticaBold();

  final dateStr = DateFormat('dd/MM/yy').format(bill.createdAt.toDate());
  final timeStr = DateFormat('HH:mm').format(bill.createdAt.toDate());

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(
        70 * PdfPageFormat.mm, // 47mm width for thermal printer
        double.infinity, // Unlimited length
        marginAll: 3 * PdfPageFormat.mm, // Minimal margins
      ),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // Header - Company Info
            pw.Text(
              'SASTHA INTERNATIONAL',
              style: pw.TextStyle(font: boldFont, fontSize: 9),
              textAlign: pw.TextAlign.center,
            ),
            pw.Text(
              'TRADINGS(SG) PTE. LTD.',
              style: pw.TextStyle(font: boldFont, fontSize: 9),
              textAlign: pw.TextAlign.center,
            ),
            pw.Text(
              '634 VEERASAMY ROAD',
              style: pw.TextStyle(font: font, fontSize: 7),
              textAlign: pw.TextAlign.center,
            ),
            pw.Text(
              '#01-140 SINGAPORE(200634)',
              style: pw.TextStyle(font: font, fontSize: 7),
              textAlign: pw.TextAlign.center,
            ),
            pw.Text(
              'sasthasga@gmail.com',
              style: pw.TextStyle(font: font, fontSize: 7),
              textAlign: pw.TextAlign.center,
            ),
            pw.Text(
              'Ph: +6580134772',
              style: pw.TextStyle(font: font, fontSize: 7),
              textAlign: pw.TextAlign.center,
            ),

            // Divider
            pw.SizedBox(height: 2),
            pw.Text(
              '========================================',
              style: pw.TextStyle(font: font, fontSize: 7),
            ),
            pw.SizedBox(height: 2),

            // Bill Info
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
            ),

            pw.Text(
              '========================================',
              style: pw.TextStyle(font: font, fontSize: 7),
            ),
            pw.SizedBox(height: 2),

            // Items Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    'ITEM',
                    style: pw.TextStyle(font: boldFont, fontSize: 7),
                  ),
                ),
                pw.Container(
                  width: 25,
                  child: pw.Text(
                    'QTY',
                    style: pw.TextStyle(font: boldFont, fontSize: 7),
                    textAlign: pw.TextAlign.left,
                  ),
                ),
                pw.Container(
                  width: 35,
                  child: pw.Text(
                    'PRICE',
                    style: pw.TextStyle(font: boldFont, fontSize: 7),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.Container(
                  width: 35,
                  child: pw.Text(
                    'TOTAL',
                    style: pw.TextStyle(font: boldFont, fontSize: 7),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
            ),

            pw.Text(
              '-----------------------------------------------------------------------',
              style: pw.TextStyle(font: font, fontSize: 7),
            ),

            // Items List
            ...bill.items.asMap().entries.map((entry) {
              final item = entry.value;
              return pw.Column(
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          item.name,
                          style: pw.TextStyle(font: font, fontSize: 7),
                          maxLines: 2,
                        ),
                      ),
                      pw.Container(
                        width: 25,
                        child: pw.Text(
                          '${item.quantity}',
                          style: pw.TextStyle(font: font, fontSize: 7),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Container(
                        width: 35,
                        child: pw.Text(
                          '\$${item.price.toStringAsFixed(2)}',
                          style: pw.TextStyle(font: font, fontSize: 7),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.SizedBox(width: 5),
                      pw.Container(
                        width: 35,
                        child: pw.Text(
                          '\$${item.total.toStringAsFixed(2)}',
                          style: pw.TextStyle(font: font, fontSize: 7),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 5),
                ],
              );
            }).toList(),

            pw.Text(
              '-----------------------------------------------------------------------',
              style: pw.TextStyle(font: font, fontSize: 7),
            ),

            // Totals Section
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'SUBTOTAL:',
                  style: pw.TextStyle(font: font, fontSize: 8),
                ),
                pw.Text(
                  '\$${currentBilltotal.toStringAsFixed(2)}',
                  style: pw.TextStyle(font: boldFont, fontSize: 8),
                ),
              ],
            ),

            if (discountAmount > 0) ...[
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'DISCOUNT:',
                    style: pw.TextStyle(font: font, fontSize: 8),
                  ),
                  pw.Text(
                    '-\$${(discountAmount).toStringAsFixed(2)}',
                    style: pw.TextStyle(font: font, fontSize: 8),
                  ),
                ],
              ),
            ],

            // if (bill.previousUnpaid != 0.0) ...[
            //   pw.Row(
            //     mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            //     children: [
            //       pw.Text(
            //         'PREV. UNPAID:',
            //         style: pw.TextStyle(font: font, fontSize: 8),
            //       ),
            //       pw.Text(
            //         '\$${bill.previousUnpaid.toStringAsFixed(2)}',
            //         style: pw.TextStyle(font: font, fontSize: 8),
            //       ),
            //     ],
            //   ),
            // ],
            pw.Text(
              '========================================',
              style: pw.TextStyle(font: font, fontSize: 7),
            ),
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
            if (bill.paidAmount > 0) ...[
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
            ],

            // if (showTallied) ...[
            //   pw.SizedBox(height: 2),
            //   pw.Text(
            //     'Previous bills tallied',
            //     style: pw.TextStyle(font: font, fontSize: 7),
            //     textAlign: pw.TextAlign.center,
            //   ),
            // ],
            pw.Text(
              '========================================',
              style: pw.TextStyle(font: font, fontSize: 7),
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
            // Footer
            pw.SizedBox(height: 10),

            pw.Text(
              'We appreciate your business!',
              style: pw.TextStyle(font: font, fontSize: 7),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 5),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Left side: Customer sign
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (signBytes != null)
                      pw.Image(
                        pw.MemoryImage(signBytes),
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
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Customer Sign',
                      style: pw.TextStyle(font: font, fontSize: 7),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),

                // Right side: Bank details
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Container(
                      width: 120,
                      height: 30,
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        '',
                        style: pw.TextStyle(font: font, fontSize: 7),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'DBS BANK A/C: 0721264374',
                      style: pw.TextStyle(font: font, fontSize: 6),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 5), // Extra space for cutting
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
