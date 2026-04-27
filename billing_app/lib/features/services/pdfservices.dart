import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

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

Future<void> generateShopBalancePdf(
  List<Map<String, dynamic>> shopsData,
) async {
  final pdf = pw.Document();

  final fontRegular = pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
  );
  final fontBold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
  );

  for (var shopData in shopsData) {
    final String shopName = shopData['shopName'] as String;
    final List<Bill> bills = shopData['bills'] as List<Bill>;
    final double totalUnPaid = (shopData['totalUnPaid'] as num).toDouble();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    shopName,
                    style: pw.TextStyle(font: fontBold, fontSize: 18),
                  ),
                  pw.Text(
                    DateFormat('dd/MM/yyyy').format(DateTime.now()),
                    style: pw.TextStyle(font: fontRegular, fontSize: 12),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: ['Bill No', 'Date', 'Total Amount', 'Balance'],
              data:
                  bills.map((bill) {
                    return [
                      bill.billNumber,
                      DateFormat('dd/MM/yyyy').format(bill.createdAt.toDate()),
                      '\$ ${bill.discountedTotal.toStringAsFixed(2)}',
                      '\$ ${bill.balance.toStringAsFixed(2)}',
                    ];
                  }).toList(),
              headerStyle: pw.TextStyle(font: fontBold, fontSize: 10),
              cellStyle: pw.TextStyle(font: fontRegular, fontSize: 10),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellAlignment: pw.Alignment.centerLeft,
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
              },
            ),
            pw.SizedBox(height: 10),
            pw.Divider(),
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Overall Total: \$ ${totalUnPaid.toStringAsFixed(2)}',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 14,
                  color: PdfColors.red,
                ),
              ),
            ),
            pw.SizedBox(height: 20),
          ];
        },
      ),
    );
  }

  final bytes = await pdf.save();
  final dir = await getApplicationDocumentsDirectory();
  final file = File(
    '${dir.path}/Shop_Balance_Report_${DateFormat('ddMMyyyy').format(DateTime.now())}.pdf',
  );
  await file.writeAsBytes(bytes);
  await OpenFilex.open(file.path);
}

Future<void> generateSingleShopPendingBillsPdf(
  String shopName,
  List<Bill> bills,
  double totalUnPaid,
) async {
  final pdf = pw.Document();

  final font = pw.Font.helvetica();
  final boldFont = pw.Font.helveticaBold();

  // Sort bills by date to match the list style
  bills.sort((a, b) => a.createdAt.compareTo(b.createdAt));

  final double totalNetTotal = bills.fold(
    0,
    (sum, b) => sum + b.discountedTotal,
  );

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (pw.Context context) {
        return [
          // ---------------- Header (Centered) ----------------
          pw.Center(
            child: pw.Text(
              'SASTHA INTERNATIONAL',
              style: pw.TextStyle(font: boldFont, fontSize: 18),
            ),
          ),
          pw.Center(
            child: pw.Text(
              'TRADINGS(SG) PTE. LTD.',
              style: pw.TextStyle(font: boldFont, fontSize: 18),
            ),
          ),
          pw.Center(
            child: pw.Text(
              '634 VEERASAMY ROAD',
              style: pw.TextStyle(font: font, fontSize: 12),
            ),
          ),
          pw.Center(
            child: pw.Text(
              '#01-140 SINGAPORE(200634)',
              style: pw.TextStyle(font: font, fontSize: 12),
            ),
          ),
          pw.Center(
            child: pw.Text(
              'sasthasga@gmail.com',
              style: pw.TextStyle(font: font, fontSize: 12),
            ),
          ),
          pw.Center(
            child: pw.Text(
              'Ph: +6580134772',
              style: pw.TextStyle(font: font, fontSize: 12),
            ),
          ),
          pw.SizedBox(height: 15),
          pw.Center(
            child: pw.Text(
              'Customer Outstanding',
              style: pw.TextStyle(font: boldFont, fontSize: 15),
            ),
          ),
          pw.SizedBox(height: 25),

          // ---------------- Info (Left Aligned) ----------------
          pw.Text(
            'TO DATE: ${DateFormat('dd-MM-yyyy').format(DateTime.now())}',
            style: pw.TextStyle(font: font, fontSize: 11),
          ),
          pw.Text(
            'CUST : $shopName',
            style: pw.TextStyle(font: font, fontSize: 11),
          ),
          pw.SizedBox(height: 15),

          // ---------------- Table Header ----------------
          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(width: 1),
                bottom: pw.BorderSide(width: 1),
              ),
            ),
            padding: const pw.EdgeInsets.symmetric(vertical: 6),
            child: pw.Row(
              children: [
                pw.SizedBox(
                  width: 30,
                  child: pw.Text(
                    'SNo',
                    style: pw.TextStyle(font: boldFont, fontSize: 11),
                  ),
                ),
                pw.Expanded(
                  flex: 3,
                  child: pw.Text(
                    'Invoice No',
                    style: pw.TextStyle(font: boldFont, fontSize: 11),
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    'Invoice Date',
                    style: pw.TextStyle(font: boldFont, fontSize: 11),
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    'Net Total',
                    style: pw.TextStyle(font: boldFont, fontSize: 11),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    'Balance',
                    style: pw.TextStyle(font: boldFont, fontSize: 11),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ],
            ),
          ),

          // ---------------- Table Data ----------------
          ...bills.asMap().entries.map((entry) {
            final int index = entry.key + 1;
            final Bill bill = entry.value;
            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Row(
                children: [
                  pw.SizedBox(
                    width: 30,
                    child: pw.Text(
                      '$index',
                      style: pw.TextStyle(font: font, fontSize: 11),
                    ),
                  ),
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text(
                      bill.billNumber,
                      style: pw.TextStyle(font: font, fontSize: 11),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      DateFormat('dd-MM-yyyy').format(bill.createdAt.toDate()),
                      style: pw.TextStyle(font: font, fontSize: 11),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      bill.discountedTotal.toStringAsFixed(2),
                      style: pw.TextStyle(font: font, fontSize: 11),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      bill.balance.toStringAsFixed(2),
                      style: pw.TextStyle(font: font, fontSize: 11),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),

          // ---------------- Total Row ----------------
          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(width: 1),
                bottom: pw.BorderSide(width: 1),
              ),
            ),
            padding: const pw.EdgeInsets.symmetric(vertical: 6),
            child: pw.Row(
              children: [
                pw.SizedBox(width: 30),
                pw.Expanded(
                  flex: 3,
                  child: pw.Text(
                    'Total :',
                    style: pw.TextStyle(font: boldFont, fontSize: 12),
                  ),
                ),
                pw.Expanded(flex: 2, child: pw.SizedBox()),
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    totalNetTotal.toStringAsFixed(2),
                    style: pw.TextStyle(font: boldFont, fontSize: 12),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    totalUnPaid.toStringAsFixed(2),
                    style: pw.TextStyle(font: boldFont, fontSize: 12),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 40),

          // ---------------- Footer ----------------
          pw.Text(
            'Ac Name : Sastha International Tradings PTE. LTD',
            style: pw.TextStyle(font: font, fontSize: 12),
          ),
          pw.Text(
            'AC Number : 0721264374',
            style: pw.TextStyle(font: font, fontSize: 12),
          ),
          pw.Text(
            'Bank Name : DBS',
            style: pw.TextStyle(font: font, fontSize: 12),
          ),
          pw.Text(
            'Paynow Number : 202442413M',
            style: pw.TextStyle(font: font, fontSize: 12),
          ),
        ];
      },
    ),
  );

  final bytes = await pdf.save();
  final dir = await getApplicationDocumentsDirectory();
  final file = File(
    '${dir.path}/${shopName.replaceAll(' ', '_')}_Pending_Bills_${DateFormat('ddMMyyyy').format(DateTime.now())}.pdf',
  );
  await file.writeAsBytes(bytes);
  await OpenFilex.open(file.path);
}
